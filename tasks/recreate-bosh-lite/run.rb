#!/usr/bin/env ruby

require_relative '../../lib/bosh-lite-manager.rb'
require 'ostruct'

iaas = ENV['IAAS']
deployment_id = ENV['DEPLOYMENT_NAME']
domain_name = ENV['BOSH_LITE_DOMAIN_NAME']
bosh_lite_user = ENV['BOSH_USER']
bosh_lite_password = ENV['BOSH_LITE_ADMIN_PASSWORD']
bosh_lite_deployment_name = ENV["#{iaas.upcase}_BOSH_LITE_NAME"]
bosh_private_key = ENV['BOSH_PRIVATE_KEY']

bosh_lite_url = "https://#{deployment_id}.#{domain_name}"

if iaas == 'azure' || iaas == 'gcp'
  bosh_director_user = ENV["#{iaas.upcase}_BOSH_DIRECTOR_USER"]
  bosh_director_password = ENV["#{iaas.upcase}_BOSH_DIRECTOR_PASSWORD"]
  bosh_director_target = "10.0.0.6"
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

credentials_struct = OpenStruct.new({
  'gcp_bosh_lite_admin_password' => bosh_lite_password,
  'gcp_bosh_lite_hm_password' => ENV['BOSH_LITE_HM_PASSWORD'],
  'gcp_bosh_lite_nats_password' => ENV['BOSH_LITE_NATS_PASSWORD'],
  'gcp_bosh_lite_blobstore_agent_password' => ENV['BOSH_LITE_BLOBSTORE_AGENT_PASSWORD'],
  'gcp_bosh_lite_blobstore_director_password' => ENV['BOSH_LITE_BLOBSTORE_DIRECTOR_PASSWORD'],
  'gcp_bosh_lite_postgres_password' => ENV['BOSH_LITE_POSTGRES_PASSWORD']
})

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
                               bosh_private_key: bosh_private_key,
                               credentials_struct: credentials_struct
                              )

manager.recreate
