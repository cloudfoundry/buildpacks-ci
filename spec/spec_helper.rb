# encoding: utf-8
RSpec.configure do |config|
  $stdout.sync = true
  config.filter_run_excluding concourse_test: true

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

  def run(cmd)
    fly("i -b #{@id} -s one-off -- bash -c '#{cmd} && sleep 5'")
  end
end
