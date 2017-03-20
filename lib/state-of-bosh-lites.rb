# encoding: utf-8

require 'json'
require 'yaml'
require_relative './git-client'

class StateOfBoshLites

  attr_reader :state_of_environments, :environments

  def initialize
    @state_of_environments = []
    @gcp_environment_names = %w(lts-1.buildpacks-gcp.ci
                                lts-2.buildpacks-gcp.ci
                                lts-3.buildpacks-gcp.ci
                                lts-4.buildpacks-gcp.ci)

    @environments = { 'gcp' => @gcp_environment_names }

    @languages = %w(binary dotnet-core go hwc java multi nodejs php python ruby staticfile)
  end

  def get_states!(resource_pools_dir: nil, git_pull: true)
    raise "resource_pools_dir is required" if resource_pools_dir.nil?

    Dir.chdir(resource_pools_dir) do
      GitClient.pull_current_branch if git_pull
      get_all_environment_statuses

      @languages.each do |language|
        state_of_environments.push({'name' => language, 'status' => get_lock_status("edge-shared-environments", language)})
      end
    end

    state_of_environments
  end

  def get_environment_status(environment, iaas)
    type = environment.split('-').first

    resource_type = "cf-#{type}#{iaas=='aws' ? '' : '-'+ iaas}-environments"

    get_lock_status(resource_type, environment)
  end

  def display_state(output_type)
    unless %w(json text yaml).include? output_type
      raise "Invalid output type: #{output_type}"
    end

    puts "\n"
    if output_type == 'json'
      puts state_of_environments.to_json
    elsif output_type == 'yaml'
      puts state_of_environments.to_yaml
    elsif output_type == 'text'
      state_of_environments.each do |env|
        if env['status'].nil?
          # escape sequence colors yellow
          puts "#{env['name']}: \n  \e[33mDoes not currently exist in pool\e[0m"
        else
          if env['status']['claimed']
            # escape sequence colors red
            env_status = "\e[31mclaimed\e[0m"
          else
            # colors green
            env_status = "\e[32munclaimed\e[0m"
          end
          pipeline = env['status']['job'].split()[0].split('/')[0]
          job = env['status']['job'].split()[0].split('/')[1]
          build_number = env['status']['job'].split()[2]
          puts "#{env['name']}: \n  #{env_status} by job: #{env['status']['job']} \n\t https://buildpacks.ci.cf-app.com/teams/main/pipelines/#{pipeline}/jobs/#{job}/builds/#{build_number}\n"
        end
      end
    end
  end

  def bosh_lite_in_pool?(deployment_id)
    bosh_lite_env = state_of_environments.find {|env| deployment_id == env['name'] }
    !bosh_lite_env['status'].nil?
  end

  private

  def get_all_environment_statuses
    environments.each do |iaas, environment_names|
      environment_names.each do |env|
        state_of_environments.push({'name' => env, 'status' => get_environment_status(env, iaas)})
      end
    end
  end

  def get_lock_status(resource_type, lock)
    if File.exist?("#{resource_type}/claimed/#{lock}")
      claimed = true
      regex = / (.*) claiming: #{lock}/
    elsif File.exist?("#{resource_type}/unclaimed/#{lock}")
      claimed = false
      regex = / (.*) unclaiming: #{lock}/
    else
      return nil
    end

    #find which job claimed / unclaimed the environment
    recent_commits = GitClient.get_list_of_one_line_commits(Dir.pwd, 1000)

    most_recent_commit = recent_commits.select do |commit|
      commit.match regex
    end.first

    concourse_job = nil
    if most_recent_commit
      most_recent_commit.match regex
      concourse_job = $1
    end

    {'claimed' => claimed, 'job' => concourse_job}
  end

end
