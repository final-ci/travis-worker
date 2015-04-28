require 'spec_helper'
require 'travis/worker/reporter'
require 'travis/support'
require 'travis/support/amqp'

describe Travis::Worker::Reporter do
  include_context 'march_hare connection'

  let(:channel)     { connection.create_channel }
  let(:routing_key) { 'reporting.jobs.logs' }
  let(:queue)       { channel.queue(routing_key, :durable => true) }
  let(:reporting_exchange) { channel.exchange('reporting', :type => :topic, :durable => true) }
  let(:reporter)    { described_class.new('staging-1',
    Travis::Amqp::Publisher.jobs('builds', unique_channel: true, dont_retry: true),
    Travis::Amqp::Publisher.jobs('logs', unique_channel: true, dont_retry: true)
  ) }

  include Travis::Worker::Utils::Serialization

  describe 'notify' do
    before :each do
      queue.purge
      queue.bind(reporting_exchange, :routing_key => routing_key)
    end




    it 'publishes log chunks' do
      reporter.notify('build:log', :log => '...')
      sleep 0.5
      meta, payload = queue.get

      expect(decode(payload)).to eq({ :log => '...', :uuid => Travis.uuid })
      expect(meta.properties.type).to eq('build:log')
    end




    it 'publishes log chunks' do

      reporter.notify('build:log', :log => '...')
      meta, payload = queue.get

      expect(decode(payload)).to eq({ :log => '...', :uuid => Travis.uuid })
      expect(meta.properties.type).to eq('build:log')
    end
  end
end
