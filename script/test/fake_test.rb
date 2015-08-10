$: << 'lib' << 'spec'
require 'support/fake_amqp'

require 'travis/worker'
require 'travis/worker/application'
require 'travis/worker/instance'
require 'travis/worker/platform'

require 'support/fake_virtual_machine'

vm = Travis::Worker::VirtualMachine::Fake.new('fake')

reporter = Travis::Worker::Reporter.new(
  vm.name,
  StreemFaker.new('builds'),
  StreemFaker.new('logs'),
  StreemFaker.new('test_results')
)

payload = {
  'job' => { 'id' => 123 },
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
}

vm.sandboxed({}) do
  job_runner = Travis::Worker::Job::Runner.new(
    payload,
    vm,
    reporter,
    {},
    'name'
  );
  job_runner.run
end
