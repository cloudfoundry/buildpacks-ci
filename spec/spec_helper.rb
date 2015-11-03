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

end
