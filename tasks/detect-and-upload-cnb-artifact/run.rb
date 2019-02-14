# need to take buildpack, go mod vendor it
#
# we release packaged cnb's
# so we need two pipelines

Dir.chdir('..') do
  buildpack_dir = File.join(Dir.pwd, 'buildpack-git')
  buildpack_name = ENV.fetch('BUILDPACK_NAME')

  producer = CNBArtifactProducer.new(buildpack_dir, buildpack_name)
  producer.run!
end