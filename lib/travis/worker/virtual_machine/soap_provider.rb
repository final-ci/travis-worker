require 'travis/support'
require 'travis/worker/ssh/session'
require 'savon'
require 'nokogiri'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash'

module Travis
  module Worker
    module VirtualMachine
      class SoapProvider
        include Logging

        class << self
          def vm_count
            Travis::Worker.config.vms.count
          end

          def vm_names
            vm_count.times.map { |num| "#{Travis::Worker.config.vms.name_prefix}-#{num + 1}" }
          end
        end

        log_header { "#{name}:worker:virtual_machine:soap_provider" }

        attr_reader :name, :ip, :endpoint, :vm

        def initialize(name)
          @name = name
        end

        def prepare
          info "soap API adapter prepared"
        end

        def sandboxed(opts = {})
          create_server(opts)
          yield
        ensure
          session.close if @session
          destroy_server(opts)
        end

        def create_server(opts = {})
          @vm = create_vm opts
        end

        def destroy_server(opts = {})
          release_vm if vm
          @session = nil
        end

        def session
          #create_server unless clone
          @session ||= Ssh::Session.new(name,
            :host => ip_address,
            :port => soap_config.port || 22,
            :username => soap_config.username,
            :private_key_path => soap_config.private_key_path,
            :buffer => Travis::Worker.config.shell.buffer,
            :timeouts => Travis::Worker.config.timeouts,
          )
        end

        def full_name
          "#{Travis::Worker.config.host}:travis-soap-#{name}"
        end

        private

          def ip_address
            vm[:ip]
          end

          def create_vm(opts = {})
            builder = Nokogiri::XML::Builder.new do |xml|
              xml.xml {
                xml.folder soap_config.vms_folder
                xml.templateName (template_name(opts))
                xml.guid Travis.uuid
                xml.requestorUserName (opts[:requestor] || soap_config.requestor_user_name || "CZ\\tester")
                xml.testId opts[:job_id]
              } 
            end
            begin
              response = client.call(:provision_machine, message: { specification: builder.doc.root.to_s } )
              px =  Nokogiri.parse(response.body[:provision_machine_response][:provision_machine_result]);
              ip = px.xpath("//IP").first.inner_html.to_s
              name = px.xpath("//name").first.inner_html.to_s

              info "Got PC with IP: #{ip}, name: #{name}"
              {:name => name, :ip => ip}
            rescue
              error "Machine deployment failed: #{$!.inspect}, #{$@}"
              raise
            end
          end

          def release_vm
            response = client.call(:release_machine, message: { machine_name: vm[:name] } )
          rescue
            error "Machine undeploy failed: #{$!.inspect}, #{$@}"
            raise
          end

          def soap_config
            Travis::Worker.config.soap_provider
          end

          def client_config
	    raise "soap.service_endpoint must be specified!" if soap_config.service_endpoint.blank?
            res = {
              env_namespace: :s,
              namespace_identifier: nil,
              element_form_default: :qualified,
              open_timeout: 1200,
              read_timeout: 1600
            }.deep_merge(soap_config.service_config.symbolize_keys)
            res[:wsdl] = soap_config.service_endpoint
            res[:wsdl] << "?wsdl" unless res[:wsdl] =~ /\?wsdl\z/
            res
          end

          def client
            @client ||= Savon.client(client_config)
          end

          def template_name(opts)
            if soap_config.image_override
              soap_config.image_override
            else
              raise "Could not construct templateName, dist field must not be empty" unless opts[:dist]

              [ soap_config.template_name_prefix, 
                opts[:dist], 
                opts[:group]
              ].select(&:present?).join('_')
            end
          end

      end
    end
  end
end

