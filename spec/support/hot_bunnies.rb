shared_context "march_hare connection" do
  let(:connection) {
    Travis::Amqp.config = { hostname: '127.0.0.1' }
    Travis::Amqp.connect
  }
  after(:each)     { Travis::Amqp.disconnect;sleep 0.1 }
end
