require 'travis/support'
require 'travis/worker/ssh/session'
require 'travis/worker/virtual_machine/base'

module Travis
  module Worker
    module VirtualMachine
      class StaticMachine < Base

        def create_server(opts = {})
          @ips = Array(Travis::Worker.config.static_machine.ip)
          raise "The static_machine provider requires the static_machine.ip field in config file!" unless @ips
          raise "Defined count of static_machine.ip differ form vms.count" if @ips.size != Travis::Worker.config.vms.count
        end

        def destroy_server(opts = {})
          @session = nil
        end

        private

          def ip_address
            @ips[worker_number - 1]
          end


      end
    end
  end
end
