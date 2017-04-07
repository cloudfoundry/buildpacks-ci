#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'erb'
require 'ostruct'

class GCPTerraformDeployer
  attr_reader :terraform_dir, :bosh_init_dir

  def initialize(terraform_dir, bosh_init_dir)
    @terraform_dir = terraform_dir
    @bosh_init_dir = bosh_init_dir
  end

  def run!
    begin
      puts "Generating concourse.tf..."
      generate_terraform

      puts "Logging in to gcloud..."
      gcloud_login

      puts "Configuring gcloud..."
      gcloud_set_config

      puts "Creating terraform service account..."
      gcloud_add_terraform_account

      puts "Applying terraform..."
      apply_terraform

      puts "Generating #{bosh_init_dir}/bosh.yml..."
      generate_bosh_yaml

      puts "Deploying BOSH director..."
      deploy_bosh_director

      puts "Updating static IP address in Concourse manifest..."
      update_static_ips

      display_name_servers

      puts "Done!"
    ensure
      puts "Deleting terraform service account..."
      gcloud_delete_terraform_account

      puts "Deleting concourse.tf..."
      delete_terraform
    end
  end

  def run_or_exit(command)
    exit 1 unless system command
  end

  def generate_terraform
    Dir.chdir(terraform_dir) do
      ssl_keys = YAML.load(`lpass show 'deployments-buildpacks.yml' --notes`)
      ssl_struct = OpenStruct.new(ssl_keys)

      terraform_erb = ERB.new(File.read('concourse.tf.erb'))
      terraform_tf = terraform_erb.result(ssl_struct.instance_eval {binding})

      File.write('concourse.tf', terraform_tf)
    end
  end

  def generate_bosh_yaml
    Dir.chdir(bosh_init_dir) do
      deployments = YAML.load(`lpass show 'deployments-buildpacks.yml' --notes`)

      deployments_struct = OpenStruct.new(deployments)

      bosh_erb = ERB.new(File.read('bosh.yml.erb'))
      bosh_yaml = bosh_erb.result(deployments_struct.instance_eval {binding})

      File.write('bosh.yml', bosh_yaml)
    end
  end

  def update_static_ips
    puts 'The following static IP addresses have been created:'

    concourse_ip = YAML.load(`gcloud compute addresses describe concourse`)['address']
    puts "\tconcourse: #{concourse_ip}"
    update_concourse_manifest(concourse_ip)

    puts "Concourse deployment manifest updated"
  end

  def update_concourse_manifest(static_ip)
    manifest_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'deployments', 'concourse-gcp', 'manifest.yml.erb'))
    manifest = YAML.load_file(manifest_file)

    web_group = manifest['instance_groups'].select do |group|
      group['name'] == 'web'
    end.first

    network = web_group['networks'].select do |network|
      network['name'] == 'vip'
    end.first

    network['static_ips'] = [static_ip]

    File.write(manifest_file, manifest.to_yaml)

    commit_file(manifest_file)
  end

  def commit_file(file)
    run_or_exit "git add #{file}"
    run_or_exit 'git config --global user.email "cf-ci-bot@suse.de"'
    run_or_exit 'git config --global user.name "SUSE CF CI Bot"'
    run_or_exit "git commit -m 'Update BOSH-lite manifest for new GCP deployment'"
    run_or_exit 'git pull -r'
    run_or_exit 'git push'
  end

  def display_name_servers
    puts 'An NS record has been created for buildpacks-gcp.ci.cf-app.com. with name servers:'
    name_servers.each { |ns| puts "\t#{ns}" }
    puts 'Update the NS record for this domain in AWS Route 53 with these values'
  end

  def name_servers
    record_sets = `gcloud dns record-sets list --zone buildpacks`

    ns_record = record_sets.split("\n").select do |line|
      line.include?('NS')
    end.first

    ns_record.split(' ').last.split(',')
  end

  def deploy_bosh_director
    Dir.chdir(bosh_init_dir) do
      run_or_exit "gcloud compute copy-files bosh.yml pivotal@bosh-bastion-concourse:~/bosh.yml"
      gcloud_ssh 'ssh-keygen -t rsa -f ~/.ssh/bosh -C bosh'
      gcloud_ssh "METADATA=\"bosh:`cat ~/.ssh/bosh.pub`\"; echo \"$METADATA\" > ~/.ssh/bosh-edited.pub"
      gcloud_ssh "gcloud compute project-info add-metadata --metadata-from-file sshKeys=~/.ssh/bosh-edited.pub"
      puts 'Waiting for startup scripts to finish'
      # `ps` returns at least 2 results for grepping `run-startup-scripts` here:
      # the grep process and the bash shell process wrapping the grep
      startup_scripts_running = true
      while startup_scripts_running do
        sleep 1
        putc '.'
        startup_scripts_running = `gcloud compute ssh pivotal@bosh-bastion-concourse --command 'ps -ef | grep run-startup-scripts | wc -l'`.strip > '2'
      end
      gcloud_ssh 'bosh-init deploy bosh.yml'
    end
  end

  def gcloud_ssh(command)
    run_or_exit "gcloud compute ssh pivotal@bosh-bastion-concourse --command '#{command}'"
  end


  def delete_terraform
    Dir.chdir(terraform_dir) do
      FileUtils.rm_f('concourse.tf')
    end
  end

  def gcloud_login
    #this is set up on our machines now; maybe figure out how to automate this
    #later
    run_or_exit "gcloud auth login"
  end

  def gcloud_set_config
    run_or_exit "gcloud config set project cf-buildpacks"
    run_or_exit "gcloud config set compute/zone us-east1-c"
    run_or_exit "gcloud config set compute/region us-east1"
  end

  def gcloud_add_terraform_account

    run_or_exit "gcloud iam service-accounts create terraform-bosh"

    run_or_exit("gcloud iam service-accounts keys create /tmp/terraform-bosh.key.json" +
                " --iam-account terraform-bosh@cf-buildpacks.iam.gserviceaccount.com")

    run_or_exit("gcloud projects add-iam-policy-binding cf-buildpacks" +
                " --member serviceAccount:terraform-bosh@cf-buildpacks.iam.gserviceaccount.com" +
                " --role roles/editor")
    ENV['GOOGLE_CREDENTIALS'] = File.read('/tmp/terraform-bosh.key.json')
  end

  def gcloud_delete_terraform_account
    run_or_exit "gcloud iam service-accounts delete terraform-bosh@cf-buildpacks.iam.gserviceaccount.com"
  end


  def apply_terraform
    Dir.chdir(terraform_dir) do
      run_or_exit "terraform apply"
    end
  end

end
