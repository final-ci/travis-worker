require 'travis/worker/instance'

module Travis
  module Worker
    class WorkerNotFound < Exception
      def initialize(name)
        super "Unknown worker #{name}"
      end
    end

    class Pool
      def self.create
        new(Travis::Worker.config.names, Travis::Worker.config)
      end

      attr_reader :names, :config

      def initialize(names, config)
        @names  = names
        @config = config
      end

      def start(names)
        each_worker(names) { |worker| worker.start; sleep 5 }
      end

      def stop(names, options = {})
        each_worker(names) { |worker| worker.stop(options) }
      end

      def status
        workers.map { |worker| worker.report }
      end

      def each_worker(names = [])
        names = self.names if names.empty?
        names.each { |name| yield worker(name) }
      end

      def workers
        @workers ||= names.map { |name| Worker::Instance.create(name, config) }
      end

      def worker(name)
        workers.detect { |worker| (worker.name == name) } || raise(WorkerNotFound.new(name))
      end
    end
  end
end
