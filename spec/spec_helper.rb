RSpec.configure do |config|
  $stdout.sync = true

  def fly(arg)
    target = ''
    if File.exists?(File.join(Dir.home,".flyrc"))
      target = "buildpacks"
    else
      target  = "https://#{ENV["CI_USERNAME"]}:#{ENV["CI_PASSWORD"]}@buildpacks.ci.cf-app.com/"
    end
    `fly --target #{target} #{arg}`
  end

end
