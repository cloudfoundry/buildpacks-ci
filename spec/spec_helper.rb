RSpec.configure do |config|
  $stdout.sync = true

  def fly(arg, env = {})
    target = ''
    if File.exists?(File.join(Dir.home,".flyrc"))
      target = "buildpacks"
    else
      target  = "https://#{ENV["CI_USERNAME"]}:#{ENV["CI_PASSWORD"]}@buildpacks.ci.cf-app.com/"
    end
    env_var = env.collect{|k,v| "#{k}=#{v}"}.join(' ')
    `env #{env_var} fly --target #{target} #{arg}`
  end

  def execute(cmd, env={})
    @output = fly("execute #{cmd}", env)
    @id = @output.split("\n").first.split(' ').last
    puts "latest task id=#{@id}"
  end

  def run(cmd)
    fly("i -b #{@id} -s one-off -- bash -c '#{cmd}'")
  end

end
