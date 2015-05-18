require 'travis/worker/virtual_machine/soap_provider'
require 'travis/worker/ssh/session'
require 'travis/worker'
require 'pp'
require 'hashr'

module Travis::Worker::VirtualMachine
  describe SoapProvider do
    before do
      Travis::Worker.config.soap_provider = Struct.new(
        nil, :service_endpoint, :image_override, :template_name_prefix).new(
        'http://foo.foo.foo/get/', '22', 'travis'
        )
      Travis::Worker.config.vms.count = 2
    end

    let(:soap_provider) {described_class.new('foo-1')}

    it 'it returns the correct template_name ' do

       expect(soap_provider.send(:template_name,{})).to eq(
         Travis::Worker.config.soap_provider.image_override
       )

       Travis::Worker.config.soap_provider.image_override = nil
       expect{soap_provider.send(:template_name,{})}.to raise_exception
       expect(soap_provider.send(:template_name,{:dist => 'fooo'})).to eq(
         "#{Travis::Worker.config.soap_provider.template_name_prefix}_fooo"
       )
       expect(soap_provider.send(:template_name,{:dist => 'fooo',:group => 'xxx'})).to eq(
         "#{Travis::Worker.config.soap_provider.template_name_prefix}_fooo_xxx"
       )


    end
  end
end
