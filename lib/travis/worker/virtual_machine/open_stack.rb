require 'fog'
require 'shellwords'
require 'securerandom'
require 'benchmark'
require 'travis/support'
require 'travis/worker/ssh/session'
require 'resolv'
#require 'travis/worker/virtual_machine/blue_box/template'

module Travis
  module Worker
    module VirtualMachine
      class OpenStack
        include Retryable
        include Logging

        DUPLICATE_MATCH = /testing-(\w*-?\w+-?\d*-?\d*-\d+-\w+-\d+)-(\d+)/

        DEFAULT_TEMPLATE_ID = Travis::Worker.config.open_stack.default_template_id

        USER_NAME = Travis::Worker.config.open_stack.username

        class << self
          def vm_count
            Travis::Worker.config.vms.count
          end

          def vm_names
            vm_count.times.map { |num| "#{Travis::Worker.config.vms.name_prefix}-#{num + 1}" }
          end
        end

        log_header { "#{name}:worker:virtual_machine:open_stack" }

        attr_reader :name, :password, :server, :ip_address

        def initialize(name)
          @name = name
        end

        # create a connection
        def connection
          @connection ||= Fog::Compute.new(
            provider: :openstack,
            openstack_api_key:  Travis::Worker.config.open_stack.access.api_key,
            openstack_username: Travis::Worker.config.open_stack.access.username,
            openstack_auth_url: Travis::Worker.config.open_stack.access.auth_url,
            openstack_tenant:   Travis::Worker.config.open_stack.access.tenant,
            connection_options: Travis::Worker.config.open_stack.access.connection_options || {}
          )
        end

        def create_server(opts = {})
          hostname = hostname(opts[:job_id])

          config = open_stack_vm_defaults.merge(opts.merge({
            :image_ref => template_id(opts),
            :name => hostname,
            :key_name => Travis::Worker.config.open_stack.key_pair_name
          }))

          retryable(tries: 3, sleep: 5) do
            destroy_duplicate_servers
            create_new_server(config)
          end
        end

        def create_new_server(opts)
          @password = (opts[:password] ||= Travis::Worker.config.open_stack.password || generate_password)

          opts[:user_data] = user_data(opts[:name], USER_NAME, opts[:password])

          @server = connection.servers.create(opts)
          instrument do
            Fog.wait_for(300, 3) do
              begin
                server.reload
                server.ready?
              rescue Excon::Errors::HTTPStatusError => e
                mark_api_error(e)
                false
              end
            end
          end

          allocate_and_associate_ip_address_for(server)

          info "Booted #{server.name} (#{ip_address})"
        rescue Timeout::Error, Fog::Errors::TimeoutError => e
          if server
            error "OpenStack VM would not boot within 240 seconds : id=#{server.id} state=#{server.state} vsh=#{server.vsh_id}"
          end
          Metriks.meter("worker.vm.provider.openstack.boot.timeout.#{server.vsh_id}").mark
          release_floating_ip(ip_address) if ip_address
          raise
        rescue Excon::Errors::HTTPStatusError => e
          mark_api_error(e)
          release_floating_ip(ip_address) if ip_address
          raise
        rescue Exception => e
          Metriks.meter('worker.vm.provider.openstack.boot.error').mark
          error "Booting an OpenStack VM failed with the following error: #{e.inspect}"
          release_floating_ip(ip_address) if ip_address
          raise
        end

        def hostname(suffix)
          prefix = Worker.config.host.split('.').first
          "testing-#{prefix}-#{Process.pid}-#{name}-#{suffix}"
        end

        def session
          unless server
            raise StandardError, 'VM is not currently available'
          end
          @session ||= Ssh::Session.new(name,
            :host => ip_address,
            :port => 22,
            :username => USER_NAME,
            :password => Travis::Worker.config.open_stack.password,
            :private_key_path => Travis::Worker.config.open_stack.private_key_path,
            :buffer => Travis::Worker.config.shell.buffer,
            :timeouts => Travis::Worker.config.timeouts
          )
        end

        def sandboxed(opts = {})
          create_server(opts)
          yield
        ensure
          session.close if @session
          destroy_server if server
        end

        def open_stack_vm_defaults
          {
            :username  => USER_NAME,
            :flavor_ref => Travis::Worker.config.open_stack.flavor_id,
            :nics => [{ net_id: Travis::Worker.config.open_stack.internal_network_id }]
          }
        end

        def full_name
          "#{Travis::Worker.config.host}:travis-#{name}"
        end

        def allocate_and_associate_ip_address_for(srv)
          unless srv.ready?
            info "#{srv.name} is not ready"
            return
          end

          if Travis::Worker.config.open_stack.use_floating_ip
            ip = connection.allocate_address(Travis::Worker.config.open_stack.external_network_id)
            addr = ip.body["floating_ip"]["ip"]
            connection.associate_address(srv.id, addr)
          else
            addr = srv.addresses[Travis::Worker.config.open_stack.access.tenant].first["addr"]
          end
          debug "Allocated #{addr} and assigned it to #{srv.name}"

          @ip_address = addr
        end

        def destroy_server(opts = {})
          release_floating_ip(ip_address) if Travis::Worker.config.use_floating_ip
          destroy_vm(server)
        ensure
          server = nil
          @session = nil
        end

        def prepare
          info "OpenStack API adapter prepared"
        end

        private

          def template_name(opts)
            if Travis::Worker.config.open_stack.image_override
              Travis::Worker.config.open_stack.image_override
            else
              raise "Could not construct templateName, dist field must not be empty" unless opts[:dist]
              [ Travis::Worker.config.open_stack.template_name_prefix,
                opts[:dist],
                opts[:group]
              ].select(&:present?).join('_')
            end
          end

          def template_id(opts)
            connection.images.find_all() do |img|
              img.name == template_name(opts)
            end.first.id || DEFAULT_TEMPLATE_ID
          end

          def destroy_duplicate_servers
            duplicate_servers.each do |server|
              info "destroying duplicate server #{server.name}"
              destroy_vm(server)
            end
          end

          def duplicate_servers
            connection.servers.select do |server|
              DUPLICATE_MATCH.match(server.name) do |match|
                match[1] == "#{Worker.config.host.split('.').first}-#{Process.pid}-#{name}"
              end
            end
          rescue Excon::Errors::HTTPStatusError => e
            warn "could not retrieve the current VM list : #{e.inspect}"
            mark_api_error(e)
            raise
          end

          def instrument
            info "Provisioning an OpenStack VM"
            time = Benchmark.realtime { yield }
            info "OpenStack VM provisioned in #{time.round(2)} seconds"
            Metriks.timer('worker.vm.provider.openstack.boot').update(time)
          end

          def mark_api_error(error)
            Metriks.meter("worker.vm.provider.openstack.api.error.#{error.response[:status]}").mark
            error "OpenStack API returned error code #{error.response[:status]} : #{error.inspect}"
          end

          def destroy_vm(vm)
            debug "vm is in #{vm.state} state"
            info "destroying the VM"
            retryable(tries: 3, sleep: 5) do
              vm.destroy
            end
          rescue Fog::Compute::OpenStack::NotFound => e
            warn "went to destroy the VM but it didn't exist :/ : #{e.inspect}"
          rescue Excon::Errors::HTTPStatusError => e
            warn "went to destroy the VM but there was an http status error : #{e.inspect}"
          rescue Excon::Errors::InternalServerError => e
            warn "went to destroy the VM but there was an internal server error : #{e.inspect}"
            mark_api_error(e)
          end

          def release_floating_ip(address)
            if ip_obj = connection.addresses.detect {|addr| addr.ip == address }
              info "releasing floating IP #{address}"
              connection.release_address(ip_obj.id)
            end
          end

          def generate_password
            SecureRandom.base64 12
          end

          def user_data(hostname, username, passwd)
            user_data  = %Q{#! /bin/bash\n}
            user_data += %Q{cat /etc/hosts | sed -e 's/^\\(127\\.0\\.0\\.1.*\\)localhost\\s*\\(.*\\)$/\\1localhost #{hostname} \\2/' | sudo tee /etc/hosts >/dev/null\n}
            user_data += %Q{cat /etc/hosts | sed -e 's/^\\(::1.*\\)localhost\\s*\\(.*\\)$/\\1localhost #{hostname} \\2/' | sudo tee /etc/hosts >/dev/null\n}
            user_data += %Q{sudo useradd #{username} -m -s /bin/bash || true\n}
            user_data += %Q{echo #{username}:#{passwd} | sudo chpasswd\n} if passwd
            user_data += %Q{sudo sed -i '/#{username}/d' /etc/sudoers\n}
            user_data += %Q{echo "#{username} ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null\n}
            user_data += %Q{sudo sed -i '/PasswordAuthentication/ d' /etc/ssh/sshd_config\n}
            user_data += %Q{echo 'PasswordAuthentication yes' | tee -a /etc/ssh/sshd_config >/dev/null\n}
            user_data += %Q{sudo sed -i '/UseDNS/ d' /etc/ssh/sshd_config\n}
            user_data += %Q{echo 'UseDNS no' | tee -a /etc/ssh/sshd_config >/dev/null\n}
            user_data += %Q{sudo service ssh restart}
          end

      end
    end
  end
end
