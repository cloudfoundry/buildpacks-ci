# encoding: utf-8

require 'json'
require 'yaml'
require_relative './git-client'

class StateOfBoshLites

  attr_reader :state_of_environments, :environment_names

  def initialize
    @state_of_environments = []
    @environment_names = %w(edge-1.buildpacks.ci
                            edge-2.buildpacks.ci
                            lts-1.buildpacks.ci
                            lts-2.buildpacks.ci)
  end

  def get_environment_status(environment)
    type = environment.split('-').first

    if File.exist?("cf-#{type}-environments/claimed/#{environment}")
      claimed = true
      regex = / (.*) claiming: #{environment}/
    elsif File.exist?("cf-#{type}-environments/unclaimed/#{environment}")
      claimed = false
      regex = / (.*) unclaiming: #{environment}/
    else
      raise "Unable to determine status of environment #{environment}"
    end

    #find which job claimed / unclaimed the environment
    recent_commits = GitClient.get_list_of_one_line_commits(Dir.pwd,500)

    most_recent_commit = recent_commits.select do |commit|
      commit.match regex
    end.first

    most_recent_commit.match regex
    concourse_job = $1

    {'claimed' => claimed, 'job' => concourse_job}
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
        if env['status']['claimed']
          # escape sequence colors red
          env_status = "\e[31mclaimed\e[0m"
        else
          # colors green
          env_status = "\e[32munclaimed\e[0m"
        end

        puts "#{env['name']}: \n  #{env_status} by job: #{env['status']['job']}"
      end
    end
  end

  def get_states!
    buildpacks_ci_dir = File.join(File.dirname(__FILE__), '..')

    Dir.chdir(buildpacks_ci_dir) do
      current_branch = GitClient.get_current_branch(Dir.pwd)

      GitClient.checkout_branch('resource-pools')
      GitClient.pull_current_branch

      environment_names.each do |env|
        state_of_environments.push({'name' => env, 'status' => get_environment_status(env)})
      end

      GitClient.checkout_branch(current_branch)
    end
  end
end
