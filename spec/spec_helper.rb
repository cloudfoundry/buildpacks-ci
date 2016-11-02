# encoding: utf-8
require 'tmpdir'
require 'json'

RSpec.configure do |config|
  $stdout.sync = true
  config.filter_run_excluding concourse_test: true

  # Run tests in living color, even on CI
  config.color = true
  config.tty = true

  def fly(arg, env = {})
    target = 'buildpacks'
    env_var = env.collect { |k, v| "#{k}=#{v}" }.join(' ')
    `env #{env_var} fly --target #{target} #{arg} | tee /tmp/fly.log`
  end

  def execute(cmd, env = {})
    @output = fly("execute #{cmd}", env)
    @id = @output.split("\n").first.split(' ').last
    puts "latest task id=#{@id}"
  end

  def run(cmd, sleep_time = 5)
    # 'echo 2' is to work around problem: https://concourseci.slack.com/archives/general/p1469626158002396
    output = `echo '2' | fly --target buildpacks i -b #{@id} -s one-off -- bash -c '#{cmd} && sleep #{sleep_time}' | tee /tmp/fly.log`
    # regex is to strip out the choose container output that appears in every
    # intercept (related to above problem)
    /.*choose a container: 2\n(.*)/m.match(output)
    $1
  end
end
