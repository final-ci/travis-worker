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

class QueueTester

  def start
    Travis::Amqp.connect
    @publisher = Travis::Amqp::Publisher.builds('builds.linux')
    @publisher.channel.prefetch = 1
  end

  def stop
    Travis::Amqp.disconnect
    true
  end

  def queue_job(payload)
    @publisher.publish(payload)
  end

end

payload = {
  'job' => {
    'id' => 1
  },
  'repository' => {
    'slug' => 'svenfuchs/gem-release',
  },
  'build' => {
    'id' => 1,
    'commit' => '313f61b',
    'branch' => 'master',
  },
  'config' => {
    'rvm'    => '1.8.7',
    'script' => 'rake'
  },
  'script' => <<EOF
echo "test..."
sleep 5
curl -X POST -H "Accept: application/json" -d '{"job_id": 666, "message": "text from guest api1"}' $GUEST_API_URL/jobs/1/logs
echo 'text form stdout'
curl -X POST -H "Accept: application/json" -d '{"job_id": 666, "message": "text from guest api2"}' $GUEST_API_URL/jobs/1/logs
curl -X POST -H "Accept: application/json" -d '{"job_id": 2, "name": "testName", "classname": "className", "result": "success"}' $GUEST_API_URL/jobs/1/testcases
sleep 2
curl -X POST -H "Accept: application/json" -d \'{"job_id": 1, "message": "any text"}\' $GUEST_API_URL/jobs/1/finished
sleep 2
EOF
}

puts "about to start the queue tester\n\n"

@queue_tester = QueueTester.new
@queue_tester.start

Signal.trap("INT")  { @queue_tester.stop; exit }

puts "queue tester started! \n\n"

while true do
  print 'press enter to trigger a build job for svenfuchs/gem-release, or exit to quit : '

  output = gets.chomp

  @queue_tester.stop && exit if output == 'exit'

  @queue_tester.queue_job(payload)

  puts "build payload sent!\n\n"
end
