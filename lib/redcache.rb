require "redcache/version"
require "redcache/configuration"

module Redcache
  class << self
    attr_writer :configuration

    def configure
      yield(configuration)
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

    def cache(redis_key, &block)
      return block.call if skip_cache?
      if redis_up?
        value = read_from_cache(redis_key, block) || write_into_cache(redis_key, block)
        return value unless value.nil?
      else
        block.call
      end
    end

    def skip_cache?
      configuration.skip_cache
    end

    def read_from_cache(redis_key, block)
      value = get_value(redis_key)
      if value.nil?
        log("cache.miss")
      else
        log("cache.hit")
      end
      if key_stale?(redis_key) && !value.nil?
        log("cache.stale_refresh")
        Thread.new do
          write_into_cache(redis_key, block)
        end
      end
      return value
    end

    def write_into_cache(redis_key, block)
      json = block.call
      with_redis do
        log("cache.write")
        set_value(redis_key, json)
      end
      json
    end

    def key_stale?(redis_key)
      ttl = redis.ttl(redis_key)
      return  ttl < (configuration.cache_time - configuration.stale_time)
    end

    def get_value(key)
      decrypt redis.get(key)
    end

    def set_value(key, value)
      redis.setex key, configuration.cache_time, encrypt(value)
    end

    def encrypt(value)
      return value unless encrypt?
      Fernet.generate(secret, MultiJson.encode(value))
    end

    def encrypt?
      configuration.encrypt
    end

    def decrypt(value)
      return nil if value.nil?
      return value unless encrypt?
      verifier = Fernet.verifier(secret, value)
      return MultiJson.load(verifier.message) if verifier.valid?
      return nil
    end

    def secret
      configuration.secret
    end

    def log(str)
      configuration.logger.log(log_prefix(str) => 1)
    end

    def log_prefix(str)
      [configuration.log_prefix, str].join(".")
    end
  end
end
