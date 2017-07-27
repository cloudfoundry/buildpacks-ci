#!/usr/bin/env ruby

require_relative '../../lib/bosh-lite-manager.rb'

deployment_id = ENV.fetch('DEPLOYMENT_NAME')
domain_name = ENV.fetch('BOSH_LITE_DOMAIN_NAME')
bosh_private_key = ENV.fetch('BOSH_PRIVATE_KEY')

bosh_lite_url = "https://#{deployment_id}.#{domain_name}"

bosh_lite_deployment_name = ENV.fetch("GCP_BOSH_LITE_NAME")
bosh_director_user = ENV.fetch("GCP_BOSH_DIRECTOR_USER")
bosh_director_password = ENV.fetch("GCP_BOSH_DIRECTOR_PASSWORD")
bosh_director_target = "10.0.0.6"
deployments_location = 'buildpacks-ci'

BOSH_DIRECTOR_CA_CERT_PATH="/tmp/director_ca_cert".freeze
File.write(BOSH_DIRECTOR_CA_CERT_PATH, ENV.fetch("GCP_BOSH_DIRECTOR_CA_CERT"))

deployment_dir = File.join(Dir.pwd, deployments_location, 'deployments', deployment_id)

manager = BoshLiteManager.new(iaas: 'gcp',
                               deployment_dir: deployment_dir,
                               deployment_id: deployment_id,
                               bosh_lite_deployment_name: bosh_lite_deployment_name,
                               bosh_lite_url: bosh_lite_url,
                               bosh_lite_user: nil,
                               bosh_lite_password: nil,
                               bosh_director_user: bosh_director_user,
                               bosh_director_password: bosh_director_password,
                               bosh_director_target: bosh_director_target,
                               bosh_private_key: bosh_private_key,
                               bosh_director_ca_cert_path: BOSH_DIRECTOR_CA_CERT_PATH,
                               credentials_struct: nil
                              )

manager.destroy
