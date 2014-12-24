require 'spec_helper'
require 'fernet'

Redcache.configure do |c|
  c.redis = Redis.new
  c.logger = Pliny
  c.silent = true
end

class Dummy
  def self.uuid
    SecureRandom.uuid
  end

  def self.run
    Redcache.cache "foo", uuid do |uuid|
      get_value(uuid)
    end
  end

  def self.get_value(uuid=nil)
    "bar"
  end
end

describe Redcache do
  let(:rc) { Redcache }
  let(:config) { Redcache.configuration }

  before do
    allow(rc.fernet).to receive(:generate){ "abd" }
  end

  context 'when skipping caching' do
    before do
      config.skip_cache = true
    end

    it 'does not use the cache' do
      expect(rc).to_not receive(:read_from_cache)
      Dummy.run
    end
  end

  context 'when caching' do
    before do
      config.skip_cache = false
    end

    it 'uses the cached' do
      expect(rc).to receive(:read_from_cache){ {} }
      Dummy.run
    end

    it 'shows redis as down if it times out' do
      allow(rc.redis).to receive(:ping){ raise Timeout::Error }
      expect(rc.redis_up?).to eq(false)
    end

    it 'triggers a cache write if the cache is cold' do
      allow(rc).to receive(:read_from_cache){ nil }
      expect(rc).to receive(:write_into_cache) { "" }
      Dummy.run
    end

    it 'skips cache when redis is down' do
      random = SecureRandom.uuid
      allow(Dummy).to receive(:uuid){ random }
      allow(rc).to receive(:redis_up?){ false }
      expect(rc).to_not receive(:read_from_cache)
      expect(Dummy).to receive(:get_value).with(random){ "bar" }
      Dummy.run
    end

    it 'triggers a cache refresh with a stale warm cache' do
      allow(rc).to receive(:key_stale?){ true }
      allow(rc).to receive(:get_value){ "" }
      expect(rc).to receive(:refresh_cache).once
      Dummy.run
    end
  end

  describe 'configuration' do
    it 'respects cache_time' do
      config.cache_time = 100
      expect(rc.cache_time).to eq(100)
    end

    it 'respects stale_time' do
      config.stale_time = 100
      expect(rc.stale_time).to eq(100)
    end

    it 'respects skip_cache' do
      config.skip_cache = true
      expect(rc.skip_cache?).to eq(true)
    end

    it 'knows the secret' do
      config.secret = "bar"
      expect(rc.secret).to eq("bar")
    end
  end

  it 'knows when a key is stale' do
    config.cache_time = 100
    config.stale_time = 10
    allow(rc.redis).to receive(:ttl){ 80 }
    expect(rc.key_stale?("foo")).to eq(true)

    allow(rc.redis).to receive(:ttl){ 91 }
    expect(rc.key_stale?("foo")).to eq(false)
  end

  it 'can refresh the cache' do
    p = Proc.new {}
    expect(Thread).to receive(:new)
    rc.refresh_cache("foo", p)
  end

  it 'can write into the cache' do
    p = Proc.new { "" }
    expect(rc).to receive(:set_value).with("foo", "")
    rc.write_into_cache("foo", p.call)
  end

  it 'can get a value' do
    expect(rc.redis).to receive(:get).with("foo"){ "bar" }
    expect(rc).to receive(:decrypt).with("bar")
    rc.get_value("foo")
  end

  it 'can set a value' do
    config.cache_time = 100
    config.encrypt = false
    expect(rc.redis).to receive(:setex).with("foo", 100, '"bar"')
    rc.set_value("foo", "bar")
  end

  it 'encrypts' do
    config.encrypt = true
    config.secret = "foo"
    expect(rc.fernet).to receive(:generate).with("foo", '"bar"'){ "abc" }
    rc.encrypt("bar")
  end
end
