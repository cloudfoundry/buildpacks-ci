# encoding: utf-8
require 'tmpdir'
require 'tempfile'
require 'json'

RSpec.configure do |config|
  $stdout.sync = true
  config.filter_run_excluding concourse_test: true

  # Run tests in living color, even on CI
  config.color = true
  config.tty = true

  config.before do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end
  config.after(:all) do
    $stdout = STDOUT
    $stderr = STDERR
  end

  def fly(arg, env = {})
    target = 'buildpacks'
    env_var = env.collect { |k, v| "#{k}=#{v}" }.join(' ')
    `env #{env_var} fly --target #{target} #{arg} | tee /tmp/fly.log`
  end

  def execute(cmd, env = {})
    @output = fly("execute #{cmd}", env)
    @id = @output.split("\n").first.split(' ').last
  end

  def run(cmd, sleep_time = 5)
    `fly --target buildpacks i -b #{@id} -s one-off -- bash -c '#{cmd} && sleep #{sleep_time}' | tee /tmp/fly.log`
  end
end
