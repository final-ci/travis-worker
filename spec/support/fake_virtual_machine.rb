require 'travis/support'
require 'travis/worker/ssh/session'
require 'savon'
require 'nokogiri'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash'
require 'travis/worker/virtual_machine/base'

module Travis
  module Worker
    module VirtualMachine

      class FakeSession

        def initialize(name, opts)
          @name = name
          @opts = opts
        end

        def closed?
          !@connected
        end

        def close
          @connected = false
        end

        def connect
          @connected = true
        end

        def log_silence_timeout=(_)
          #empty
        end

        def on_output(&block)
          @block = block
          block.call(
            "session initialized with name: #{@name.inspect}, " + 
            "options: #{@opts.inspect}"
          )
        end

        def forward
          a = nil
          def a.remote_to(port, ip, port2)
          end
          a
        end

        def exec(cmd)
          @block.call("executing: #{cmd.inspect}", {})
          case cmd
          when "test -f ~/build.sh" then 1
          else 0
          end
        end

        def upload_file(name, content)
          @block.call("uploading file #{name.inspect}", {})
          0
        end

      end

      class Fake < Base
        include Logging


        attr_reader :endpoint, :vm, :client

        def create_server(opts = {})
          @vm = create_vm opts
        end

        def destroy_server(opts = {})
          @session = nil
        end

        def session
          @session = FakeSession.new(name, {})
        end

        private

          def ip_address
            vm[:ip]
          end

          def create_vm(opts = {})
            ip = '255.255.255.255'
            name = "FakeMachine_#{name}"
            info "Got PC with IP: #{ip}, name: #{name}"
            {:name => name, :ip => ip}
          end
      end
    end
  end
end
