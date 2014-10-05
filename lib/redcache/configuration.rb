module Redcache
  class Configuration
    attr_accessor :redis
    attr_accessor :secret
    attr_accessor :cache_time
    attr_accessor :stale_time
    attr_accessor :encrypt
    attr_accessor :skip_cache
    attr_accessor :logger
    attr_accessor :log_prefix

    def initialize
      @cache_time = 86400
      @stale_time = 900
      @encrypt = false
      @secret = nil
      @skip_cache = false
      @logger = nil
      @log_prefix = "redcache"
    end
  end
end
