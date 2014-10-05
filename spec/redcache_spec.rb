require 'spec_helper'

Redcache.configure do |c|
  c.redis = Redis.new
  c.logger = Pliny
end

class Dummy
  def self.run
    Redcache.cache "foo" do
      get_value
    end
  end

  def self.get_value
    "bar"
  end
end

describe Redcache do

  context 'when skipping caching' do
    before do
      allow(Redcache.configuration).to receive(:skip_cache){true}
    end
    it 'does not use the cache' do
      expect(Redcache).to_not receive(:read_from_cache)
      Dummy.run
    end
  end

  context 'when caching' do
    before do
      allow(Redcache.configuration).to receive(:skip_cache){false}
    end

    it 'uses the cached' do
      expect(Redcache).to receive(:read_from_cache){ {} }
      Dummy.run
    end

    it 'triggers a cache write if the cache is cold' do
      allow(Redcache).to receive(:read_from_cache){ nil }
      expect(Redcache).to receive(:write_into_cache) { "" }
      Dummy.run
    end

    it 'skips cache when redis is down' do
      allow(Redcache).to receive(:redis_up?){ false }
      expect(Redcache).to_not receive(:read_from_cache)
      expect(Dummy).to receive(:get_value)
      Dummy.run
    end

    it 'triggers a cache refresh with a stale warm cache' do
      allow(Redcache).to receive(:key_stale?){ true }
      allow(Redcache).to receive(:get_value){ "" }
      expect(Redcache).to receive(:refresh_cache).once
      Dummy.run
    end
  end

end
