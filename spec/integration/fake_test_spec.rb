require 'spec_helper'
require 'travis/worker'
require 'travis/worker/application'
require 'travis/worker/instance'
require 'travis/worker/platform'

require 'support/fake_amqp'
require 'support/fake_virtual_machine'

describe "JobRunner" do
  let(:logs_output)   { StringIO.new }
  let(:builds_output) { StringIO.new }
  let(:vm)          { Travis::Worker::VirtualMachine::Fake.new('fake') }
  let(:platform)    { Platform.create('linux', vm) }
  let(:reporter)    { Travis::Worker::Reporter.new(
    vm.name,
    FakerPusher.new('builds', builds_output),
    FakerPusher.new('logs', logs_output),
    FakerPusher.new('test_results')
  ) }

  let(:payload) { {
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
    }
  } }

  it "runs a job in sandboxed vm" do
    vm.sandboxed({}) do
      job_runner = Travis::Worker::Job::Runner.new(payload, vm, reporter, {}, 'name');
      job_runner.run
    end

    logs_contains = [
      'session initialized with name',
      'Using worker:',
      'executing: \"test -f ~/build.sh\"',
      'uploading file \"~/build.sh\"',
      'executing: \"chmod +x ~/build.sh\"',
      'executing: \"GUEST_API_URL=http://127.0.0.1:34567 bash --login ~/build.sh\"'
    ]
    logs_contains.each do |output|
      expect(logs_output.string).to include output
    end

    builds_contains = [
      'state=>\"started\"',
      'state=>\"passed\"'
    ]

  end
end
