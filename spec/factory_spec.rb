require 'spec_helper'
require 'travis/worker/factory'
require 'travis/support/amqp'

describe Travis::Worker::Factory do

  let(:config)  { Hashr.new({ :queue => "builds.php" }) }
  let(:factory) { Travis::Worker::Factory.new('worker-name', config) }
  let(:worker)  { factory.worker }

  describe 'worker' do
    after(:each) { worker.shutdown }

    it 'returns a worker' do
      expect(worker).to be_a(Travis::Worker::Instance)
    end

    it 'has a vm' do
      expect(worker.vm.class.to_s).to eq("Travis::Worker::VirtualMachine::BlueBox")
    end

    describe 'queues' do
      it 'includes individual build queues that were listed in the configuration' do
        expect(worker.queue_name).to eq("builds.php")
      end
    end
  end
end
