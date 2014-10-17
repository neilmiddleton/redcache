require "redcache/version"
require "fernet"
require "redcache/configuration"

Fernet::Configuration.run do |config|
  config.enforce_ttl = false
end

module Redcache
  class << self
    attr_writer :configuration

    def configure
      yield(configuration)
    end

    def cache(redis_key, *args, &block)
      # return immediately if we shouldn't or can't cache
      return block.call(*args) if skip_cache? || !redis_up?
      with_redis do
        # attempt to read from cache, running and caching the block if cold
        value = read_from_cache(redis_key, *args, &block)
        if value.nil?
          value = block.call if value.nil?
          write_into_cache(redis_key, value)
        end
        return value
      end
    end

    def read_from_cache(redis_key, *args, &block)
      value = get_value(redis_key)
      value.nil? ? log("cache.miss", redis_key) : log("cache.hit", redis_key)
      refresh_cache(redis_key, *args, &block) if key_stale?(redis_key) && !value.nil?
      return value
    end

    def refresh_cache(redis_key, *args, &block)
      log("cache.stale_refresh", redis_key)
      Thread.new(*args) do |*thread_args|
        write_into_cache(redis_key, block.call(*thread_args))
      end
    end

    def write_into_cache(redis_key, value)
      with_redis do
        log("cache.write", redis_key)
        set_value(redis_key, value)
      end
      value
    end

    def get_value(key)
      decrypt redis.get(key)
    end

    def set_value(key, value)
      redis.setex key, configuration.cache_time, encrypt(value)
    end

    def key_stale?(redis_key)
      ttl = redis.ttl(redis_key)
      return  ttl < (configuration.cache_time - configuration.stale_time)
    end

    def encrypt(value)
      return prep_value(value) unless encrypt?
      fernet.generate(secret, prep_value(value))
    end

    def decrypt(value)
      return nil if value.nil?
      return value unless encrypt?
      verifier = fernet.verifier(secret, value)
      return MultiJson.load(verifier.message) if verifier.valid?
      return nil
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def redis
      configuration.redis
    end

    def redis_up?
      begin
        redis.ping
      rescue Redis::CannotConnectError
        puts "Redis is DOWN! :shitsonfire:"
        return false
      end
      return true
    end

    def with_redis(&block)
      block.call if redis_up?
    end

    def cache_time
      configuration.cache_time
    end

    def stale_time
      configuration.stale_time
    end

    def skip_cache?
      configuration.skip_cache
    end

    def test?
      ENV["RACK_ENV"] == 'test'
    end

    def prep_value(value)
      MultiJson.encode(value)
    end

    def encrypt?
      configuration.encrypt
    end

    def secret
      configuration.secret
    end

    def log(str, key)
      configuration.logger.log(log_prefix(str) => 1, :key => key) unless configuration.silent
    end

    def log_prefix(str)
      [configuration.log_prefix, str].join(".")
    end

    def fernet
      ::Fernet
    end
  end
end
