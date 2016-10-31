#!/usr/bin/env ruby

require_relative '../../lib/bosh-lite-manager.rb'

iaas = ENV['IAAS'] || 'aws'
deployment_id = ENV['DEPLOYMENT_NAME']
domain_name = ENV['DOMAIN_NAME'] || 'cf-app.com'
bosh_lite_user = ENV['BOSH_USER']
bosh_lite_password = ENV['BOSH_PASSWORD']
bosh_lite_deployment_name = ENV["#{iaas.upcase}_BOSH_LITE_NAME"]
bosh_private_key = ENV['BOSH_PRIVATE_KEY']

bosh_lite_url = "https://#{deployment_id}.#{domain_name}"

if iaas == 'azure' || iaas == 'gcp'
  bosh_director_user = ENV["#{iaas.upcase}_BOSH_DIRECTOR_USER"]
  bosh_director_password = ENV["#{iaas.upcase}_BOSH_DIRECTOR_PASSWORD"]
  bosh_director_target = "bosh.buildpacks-#{iaas}.ci.#{domain_name}"
elsif iaas == 'aws'
  bosh_director_user = bosh_director_password = bosh_director_target = nil
else
  puts "Please specify IAAS=(aws|azure|gcp)"
  exit 1
end

exit 1 unless system "rsync -a deployments-buildpacks/ deployments-buildpacks-artifacts"

Dir.chdir ('deployments-buildpacks-artifacts') do
  rubygem_mirror = ENV['RUBYGEM_MIRROR']
  exit 1 unless system "bundle config mirror.https://rubygems.org #{rubygem_mirror}"
  num_cores = `nproc`.strip
  exit 1 unless system "bundle install --jobs=#{num_cores} --retry 5"
end

deployment_dir = File.join(Dir.pwd,'deployments-buildpacks-artifacts', 'deployments', deployment_id)

manager = BoshLiteManager.new(iaas: iaas,
                               deployment_dir: deployment_dir,
                               deployment_id: deployment_id,
                               bosh_lite_user: bosh_lite_user,
                               bosh_lite_password: bosh_lite_password,
                               bosh_lite_deployment_name: bosh_lite_deployment_name,
                               bosh_lite_url: bosh_lite_url,
                               bosh_director_user: bosh_director_user,
                               bosh_director_password: bosh_director_password,
                               bosh_director_target: bosh_director_target,
                               bosh_private_key: bosh_private_key
                              )

manager.recreate
