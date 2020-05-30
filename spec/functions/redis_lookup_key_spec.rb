require 'spec_helper'
require 'puppet/functions/redis_lookup_key'

describe 'redis_lookup_key' do
  let(:function) { subject }

  let(:key) { 'foo' }
  let(:options) { {} }
  let(:context) { Puppet::Pops::Lookup::Context.new('rspec', 'hiera_redis') }

  let(:redis) { instance_double('Redis') }

  before(:each) do
    cache = {}
    allow(context).to receive(:cache).with(anything, anything) { |k, v| cache[k] = v }
    allow(context).to receive(:cache_has_key).with(anything) { |k| cache.key?(k) }
    allow(context).to receive(:cached_value).with(anything) { |k| cache[k] }

    allow(Redis).to receive(:new).and_return(redis)
    allow(redis).to receive(:type).and_return('string')
    allow(redis).to receive(:get).and_return('bar')
  end

  context 'when key does not exist' do
    before(:each) do
      allow(redis).to receive(:get).and_return(nil)
    end

    it 'raises not found' do
      expect { function.execute(key, options, context) }.to raise_error(UncaughtThrowError)
    end
  end

  context 'when key exists' do
    it 'returns the value for the provided key' do
      expect(function.execute(key, options, context)).to eq('bar')
    end

    it 'caches the fetched value' do
      function.execute(key, options, context)
      expect(context.cached_value(key)).to eq('bar')
    end
  end

  context 'when key is cached' do
    before(:each) do
      allow(context).to receive(:cache_has_key).with(key).and_return(true)
      allow(context).to receive(:cached_value).with(key).and_return('baz')
    end

    it 'returns the value from the cache' do
      expect(function.execute(key, options, context)).to eq('baz')
    end
  end

  context 'when scope is specified' do
    let(:options) { super().merge('scope' => 'common') }

    it 'fetches the expected key' do
      expect(redis).to receive(:get).with('common:'+key)
      function.execute(key, options, context)
    end
  end
end
