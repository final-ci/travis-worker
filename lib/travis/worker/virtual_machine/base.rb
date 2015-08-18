require 'travis/support'
require 'travis/worker/ssh/session'
require 'travis/worker/platform'

module Travis
  module Worker
    module VirtualMachine
      class Base
        include Logging

        class << self
          def vm_count
            Travis::Worker.config.vms.count
          end

          def vm_names
            vm_count.times.map { |num| "#{Travis::Worker.config.vms.name_prefix}-#{num + 1}" }
          end
          def provider_name
            self.to_s.sub(/\A.*:/, '').underscore
          end

        end

        log_header { "#{name}:worker:virtual_machine:#{self.provider_name}" }

        attr_reader :name, :ip, :platform_provider

        def initialize(name)
          @name = name
          @session = nil
        end

        def provider_name
          self.class.provider_name
        end

        def prepare
          info "#{self.class.provider_name} API adapter prepared"
        end

        def sandboxed(opts = {})
          @platform_provider = opts[:platform_provider] || Platform.create(opts[:os] || 'linux', provider_name)
          create_server(opts)
          yield
        ensure
          session.close if @session
          destroy_server(opts)
        end

        def create_server(opts)
          raise 'Needs to be implemented in subclass'
        end

        def destroy_server(opts)
          raise 'Needs to be implemented in subclass'
        end

        def session
          #create_server unless clone
          opts = {
            :host => ip_address,
            :port => platform_provider.port,
            :username => platform_provider.username,
            :buffer => Travis::Worker.config.shell.buffer,
            :timeouts => Travis::Worker.config.timeouts
           }
           opts[:private_key_path] = platform_provider.private_key_path if platform_provider.private_key_path
           opts[:password] = platform_provider.password if (
             platform_provider.password and !opts[:private_key_path]
           )

          @session ||= Ssh::Session.new(name, opts)
        end

        def clear_closed_session
          @session = nil if @session and !@session.closed?
          session
        end

        def full_name
          "#{Travis::Worker.config.host}:travis-#{name}-#{ip}"
        end

        private

          def worker_number
            /\w+-(\d+)/.match(name)[1].to_i
          end

          def ip_address
            @ips[worker_number - 1]
          end


      end
    end
  end
end
