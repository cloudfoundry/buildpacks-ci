#!/usr/env/bin ruby

require 'yaml'
require 'fileutils'
require 'net/http'
require 'erb'
require 'ostruct'
require 'tmpdir'

require_relative 'git-client'

class BoshLiteManager
  attr_reader :deployment_dir, :iaas, :deployment_id, :bosh_lite_user,
              :bosh_lite_password, :bosh_lite_deployment_name, :bosh_lite_url,
              :bosh_director_user, :bosh_director_password, :bosh_director_target,
              :bosh_private_key, :bosh_director_ca_cert_path, :credentials_struct

  def initialize(iaas:, deployment_dir:, deployment_id:, bosh_lite_user:,
                 bosh_lite_password:, bosh_lite_deployment_name:, bosh_lite_url:,
                 bosh_director_user:, bosh_director_password:, bosh_director_target:,
                 bosh_private_key:, bosh_director_ca_cert_path:, credentials_struct:)

    @iaas = iaas
    @deployment_dir = deployment_dir
    @deployment_id = deployment_id
    @bosh_lite_user = bosh_lite_user
    @bosh_lite_password = bosh_lite_password
    @bosh_lite_deployment_name = bosh_lite_deployment_name
    @bosh_lite_url = bosh_lite_url
    @bosh_director_user = bosh_director_user
    @bosh_director_password = bosh_director_password
    @bosh_director_target = bosh_director_target
    @bosh_director_ca_cert_path = bosh_director_ca_cert_path
    @bosh_private_key = bosh_private_key
    @credentials_struct = credentials_struct
  end

  def destroy
    setup_bosh_connection

    destroy_old_bosh_lite
  end

  def recreate
    setup_bosh_connection

    destroy_old_bosh_lite

    deploy_new_bosh_lite

    if bosh_lite_running?
      puts 'Successfully contacted BOSH lite'
    else
      puts 'Unable to contact BOSH lite after 30 minutes. Timing out'
      exit 1
    end

    # Remove deployment manifests generated from the previous recreation cycle
    # So this recreation cycle's manifest generation is fresh
    cleanup_deployment_manifests
  end

  private

  def setup_bosh_connection
    target_bosh_director
  end

  def destroy_old_bosh_lite
    delete_bosh_deployment
  end

  def deploy_new_bosh_lite
    deploy_bosh_lite
  end

  def target_bosh_director
    ENV["BOSH_CLIENT"] = bosh_director_user
    ENV["BOSH_CLIENT_SECRET"] = bosh_director_password
    ENV["BOSH_CA_CERT"] = bosh_director_ca_cert_path
    ENV["BOSH_ENVIRONMENT"] = bosh_director_target
  end

  def setup_bosh_lite_manifest
    Dir.chdir(deployment_dir) do
      #Evaluate erb and generate manifest with credentials interpolated in it
      erb_template = File.join(Dir.pwd, 'bosh-lite/bosh-lite-template.yml.erb')

      bosh_lite_erb = ERB.new(File.read(erb_template))
      bosh_lite_manifest_contents = bosh_lite_erb.result(credentials_struct.instance_eval {binding})

      # Use correct director uuid in bosh-lite manifest
      bosh_lite_manifest = YAML.load(bosh_lite_manifest_contents)
      bosh_director_uuid = `bosh status --uuid`.strip
      bosh_lite_manifest['director_uuid'] = bosh_director_uuid
      File.write('bosh-lite.yml', bosh_lite_manifest.to_yaml)
    end
  end

  def delete_bosh_deployment
    run_or_exit "echo 'yes' | bosh -u #{bosh_director_user} -p #{bosh_director_password} delete deployment #{bosh_lite_deployment_name}"
  end

  def deploy_bosh_lite
    setup_bosh_lite_manifest

    Dir.chdir(deployment_dir) do
      run_or_exit "bosh deployment bosh-lite.yml"
      run_or_exit "echo 'yes' | bosh -u #{bosh_director_user} -p #{bosh_director_password} deploy"
    end
  end

  def install_ssh_key
    ssh_key_file = File.join(Dir.mktmpdir, 'keys', 'bosh.pem')
    FileUtils.mkdir_p(File.dirname(ssh_key_file))
    File.write(ssh_key_file, bosh_private_key)

    run_or_exit "chmod 0600 #{ssh_key_file}"
    run_or_exit "ssh-add #{ssh_key_file}"

    ENV.store('BOSH_LITE_PRIVATE_KEY', ssh_key_file)
    ssh_key_file
  end

  def bosh_lite_running?
    curl_command = "curl -k --output /dev/null --silent --head --fail #{bosh_lite_url}:25555/info"
    puts "Checking BOSH Lite via curl command: #{curl_command}"

    max_wait_time = 30*60
    wait_time = 0
    wait_interval = 10
    bosh_lite_unresponsive = !system(curl_command)

    while bosh_lite_unresponsive && wait_time < max_wait_time
      bosh_lite_unresponsive = !system(curl_command)
      puts '.'
      wait_time += wait_interval
      sleep(wait_interval)
    end

    wait_time < max_wait_time
  end

  def cleanup_deployment_manifests
    Dir.chdir(deployment_dir) do
      unless Dir['*.yml'].empty?
        FileUtils.rm(Dir['*.yml'])
        GitClient.add_everything
        GitClient.safe_commit("remove deployment manifests for #{deployment_id}")
      end
    end
  end

  private

  def run_or_exit(command)
    exit 1 unless system(command)
  end
end
