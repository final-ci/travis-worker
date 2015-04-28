require 'rubygems'
require 'travis/support'
require 'travis/support/amqp'
require 'multi_json'
require 'hashr'

Travis::Amqp.config = {
  host: 'localhost',
  port: 5672,
  username: 'travisci_worker',
  password: 'travisci_worker_password',
  virtual_host: 'travisci.development'
}

#Travis.logger.level = 'DEBUG'

class Reporter

  def start
    connect
    subscribe
  end

  def stop
    Travis::Amqp.disconnect
  end

  private
  def connect
    Travis::Amqp.connect
  end

  def consumer
    Travis::Amqp::Consumer.jobs('logs', channel: { prefetch: 1 })
  end

  def subscribe
    @subscription = consumer.subscribe(ack: true, declare: true) do |headers, payload|
      p [headers.properties.getType, MultiJson.decode(payload)]
      headers.ack
    end
  end
end

puts "starting the reporter\n\n"

@reporter = Reporter.new
@reporter.start

puts "reporter started! send me some logs!! :)\n\n"

Signal.trap("INT")  { @reporter.stop; exit }

while true do
  sleep(1)
end
