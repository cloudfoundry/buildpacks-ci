# encoding: utf-8

require 'yaml'
require 'tracker_api'
require_relative '../../lib/git-client'

class BoshComponentStoryCreator
  attr_reader :components, :up_to_date, :new_versions

  def initialize
    @components = %w(bosh-lite-stemcell gcp-stemcell bosh garden-runc concourse gcp-cpi)
    @up_to_date = []
    @new_versions = {}
  end

  def run!
    components.each do |component|
      known_versions_file = File.join('public-buildpacks-ci-robots', 'bosh-deployment-components', "#{component}-versions.yml")
      known_versions = YAML.load_file(known_versions_file)

      newest_version = File.read(File.join(component,'version')).strip

      if known_versions.include? newest_version
        up_to_date.push component
      else
        new_versions[component] = newest_version
      end
    end

    display_up_to_date_versions if up_to_date.any?

    display_new_versions if new_versions.any?

    new_versions.each do |component, version|
      create_tracker_story(display_name(component), version)
      update_versions_yml(component, version)
    end
  end

  private

  def display_up_to_date_versions
    puts "\n"
    puts "The following are up-to-date:"

    up_to_date.each do |component|
      puts "- #{display_name(component)}"
    end
    puts "\n"
  end

  def display_new_versions
    puts "\n"
    puts "*** New versions detected ***" if new_versions.any?

    new_versions.each do |component, version|
      puts "- #{display_name(component)} => #{version}"
    end
    puts "\n"
  end

  def display_name(component)
    {
      'bosh-lite-stemcell' => 'bosh-warden-boshlite-ubuntu-trusty-go_agent',
      'gcp-stemcell' => 'bosh-google-kvm-ubuntu-trusty-go_agent',
      'bosh' => 'BOSH',
      'garden-runc' => 'Garden-runC',
      'concourse' => 'Concourse',
      'gcp-cpi' => 'BOSH Google CPI'
    }[component]
  end

  def create_tracker_story(component, version)
    name = "Update #{component} in BOSH deployments"
    description = <<~DESCRIPTION
                     There is a new version of #{component}: #{version}

                     Update the relevant BOSH deployment manifests in https://github.com/pivotal-cf/deployments-buildpacks
                     DESCRIPTION

    tracker_client = TrackerApi::Client.new(token: ENV['TRACKER_API_TOKEN'])
    buildpack_project = tracker_client.project(ENV['TRACKER_PROJECT_ID'])

    requester_id = ENV['TRACKER_REQUESTER_ID']

    buildpack_project.create_story(name: name,
                                   description: description,
                                   story_type: 'chore')
  end

  def update_versions_yml(component, version)
    Dir.chdir('public-buildpacks-ci-robots') do
      known_versions_file = File.join('bosh-deployment-components', "#{component}-versions.yml")
      known_versions = YAML.load_file(known_versions_file)

      known_versions.push version

      File.write(known_versions_file, known_versions.to_yaml)

      GitClient.add_file(known_versions_file)
      GitClient.safe_commit("Detected new version of #{display_name(component)}: #{version}")
    end
  end
end
