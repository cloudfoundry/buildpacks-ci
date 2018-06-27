# encoding: utf-8

require 'yaml'
require 'tracker_api'
require_relative '../../lib/git-client'

class BoshComponentStoryCreator
  attr_reader :components, :up_to_date, :new_versions

  def initialize
    @components = %w(gcp-stemcell bosh concourse gcp-cpi)
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
      create_tracker_story(component, version)
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
      'gcp-stemcell' => 'bosh-google-kvm-ubuntu-trusty-go_agent',
      'bosh' => 'BOSH',
      'concourse' => 'Concourse',
      'gcp-cpi' => 'BOSH Google CPI'
    }[component]
  end

  def create_tracker_story(component, version)
    name = "Update #{display_name(component)} for Concourse deployment"
    tracker_client = TrackerApi::Client.new(token: ENV.fetch('TRACKER_API_TOKEN'))
    buildpack_project = tracker_client.project(ENV.fetch('TRACKER_PROJECT_ID'))

    requester_id = ENV.fetch('TRACKER_REQUESTER_ID').to_i

    buildpack_project.create_story(name: name,
                                   description: get_story_description(component, version),
                                   story_type: 'chore',
                                   requested_by_id: requester_id,
                                   labels: ['concourse']
    )
  end

  def get_story_description(component, version)
    release_description = <<~DESCRIPTION
                     There is a new version of #{display_name(component)}: #{version}

                     1. Pull `buildpacks-ci`
                     1. Update `deployments/concourse-gcp/manifest.yml.erb` with your changes
                     1. Run the `bin/deploy_concourse` script from root
                     1. git push when satisfied
                     DESCRIPTION

    non_release_description = <<~DESCRIPTION
                     There is a new version of #{display_name(component)}: #{version}

                     1. Pull `buildpacks-ci`
                     1. Run the `bin/deploy_concourse` script from root
                     DESCRIPTION
    case component
    when 'concourse'
      release_description
    else
      non_release_description
    end
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
