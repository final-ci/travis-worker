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
    Travis::Amqp::Publisher.jobs('logs', unique_channel: true, dont_retry: true),
    Travis::Amqp::Publisher.jobs('test_results', unique_channel: true, dont_retry: true)
  ) }

  include Travis::Worker::Utils::Serialization

  describe 'notify' do
    before :each do
      queue.purge
      queue.bind(reporting_exchange, :routing_key => routing_key)
    end




    it 'publishes log chunks' do
      pending "REGRESSION!!!! needs to be fixed!!!"

      reporter.notify('build:log', :log => '...')
      sleep 0.5
      if defined?(Bunny)
        delivery_info, meta, payload = queue.get
        pending 'this work is not done!'
        expect('???').to eq('build:log')
      elsif defined?(MarchHare)
        meta, payload = queue.get
        expect(meta.properties.type).to eq('build:log')
      else
        fail
      end
      expect(decode(payload)).to eq({ :log => '...', :uuid => Travis.uuid })

    end
  end
end
