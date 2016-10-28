#!/usr/env/bin ruby

require 'yaml'
require 'fileutils'
require 'net/http'
require_relative 'git-client'

class BoshLiteManager
  attr_reader :deployment_dir, :iaas, :deployment_id, :bosh_lite_user,
              :bosh_lite_password, :bosh_lite_deployment_name, :bosh_lite_url,
              :bosh_director_user, :bosh_director_password, :bosh_director_target,
              :bosh_private_key

  def initialize(iaas:, deployment_dir:, deployment_id:, bosh_lite_user:,
                 bosh_lite_password:, bosh_lite_deployment_name:, bosh_lite_url:,
                 bosh_director_user:, bosh_director_password:, bosh_director_target:,
                 bosh_private_key:)

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
    @bosh_private_key = bosh_private_key
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

    update_admin_password

    # Remove deployment manifests generated from the previous recreation cycle
    # So this recreation cycle's manifest generation is fresh
    cleanup_deployment_manifests
  end

  private

  def setup_bosh_connection
    if iaas == 'aws'
      install_ssh_key(File.join(deployment_dir, '..', '..'))
    elsif iaas == 'azure' || iaas == 'gcp'
      target_bosh_director
    end
  end

  def destroy_old_bosh_lite
    if iaas == 'aws'
      delete_aws_instances
    elsif iaas == 'azure' || iaas == 'gcp'
      # Clean up and destroy old bosh-lite VM
      delete_bosh_deployment
    end
  end

  def deploy_new_bosh_lite
    if iaas == 'aws'
      deploy_aws_bosh_lite

      # Commit AWS artifacts
      Dir.chdir(deployment_dir) do
        GitClient.add_everything
        GitClient.safe_commit("recreated deployment #{deployment_id}")
      end
    elsif iaas == 'azure' || iaas == 'gcp'
      # Boot up new bosh-lite VM
      deploy_bosh_lite
    end
  end

  def deploy_aws_bosh_lite
    Dir.chdir(deployment_dir) do
      ENV['VAGRANT_CWD'] = deployment_dir
      run_or_exit "/usr/bin/vagrant up --provider=aws"
    end
  end

  def target_bosh_director
    run_or_exit "bosh target #{bosh_director_target}"
    run_or_exit "bosh login #{bosh_director_user} #{bosh_director_password}"
  end

  def setup_bosh_lite_manifest
    Dir.chdir(deployment_dir) do
      # Use correct director uuid in bosh-lite manifest
      FileUtils.copy('bosh-lite/bosh-lite-template.yml', 'bosh-lite.yml')
      bosh_lite_manifest = YAML.load_file('bosh-lite.yml')
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

  def install_ssh_key(install_dir)
    ssh_key_file = File.join(install_dir, 'keys', 'bosh.pem')
    File.write(ssh_key_file, bosh_private_key)

    run_or_exit "chmod 0600 #{ssh_key_file}"
    run_or_exit "ssh-add #{ssh_key_file}"

    ENV['BOSH_LITE_PRIVATE_KEY'] = ssh_key_file
  end

  def update_admin_password
    able_to_update_admin = system "bosh -u #{bosh_lite_user} -p admin -t #{bosh_lite_url} create user #{bosh_lite_user} #{bosh_lite_password}"
    if able_to_update_admin
      puts "Deployment working!"
    elsif iaas == 'aws'
      puts "Deployment failed: deleting instance"
      delete_aws_instances
      exit 1
    else
      puts 'Deployment failed'
      exit 1
    end
  end

  def delete_aws_instances
    Dir.chdir(deployment_dir) do
      lib_directory = File.expand_path(File.dirname(__FILE__))
      terminate_bosh_lite_script = File.expand_path(File.join(lib_directory, '..', 'scripts', 'terminate-bosh-lite'))

      run_or_exit terminate_bosh_lite_script
      FileUtils.rm_rf('.vagrant')
    end
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
