require 'travis/worker/instance'
require 'travis/worker/virtual_machine'

module Travis
  module Worker
    class Factory
      attr_reader :name, :config

      def initialize(name, config = nil)
        @name              = name
        @config            = config
      end

      def worker
        Instance.new(name, vm, queue_name, config)
      end

      def vm
        VirtualMachine.provider.new(name)
      end

      def queue_name
        config[:queue]
      end

      def config
        @config ||= Travis::Worker.config
      end
    end
  end
end
