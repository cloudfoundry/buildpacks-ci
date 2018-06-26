require 'fileutils'
require 'tmpdir'
require 'yaml'

require_relative '../../../tasks/create-new-bosh-deployment-components-story/bosh-component-story-creator'

describe BoshComponentStoryCreator do
  let(:root_dir)                      { Dir.mktmpdir }
  let(:components)                    { %w(concourse gcp-cpi)}
  let(:concourse_known_versions)      { %w(1.1) }
  let(:gcp_cpi_known_versions)        { %w(1.1) }
  let(:concourse_known_versions_file) { File.join(root_dir, 'public-buildpacks-ci-robots', 'bosh-deployment-components', 'concourse-versions.yml') }
  let(:gcp_cpi_known_versions_file)   { File.join(root_dir, 'public-buildpacks-ci-robots', 'bosh-deployment-components', 'gcp-cpi-versions.yml') }
  let(:buildpack_project)             { double(:buildpack_project, create_story: nil) }
  let(:tracker_client)                { double(:tracker_client, project: buildpack_project) }

  subject { described_class.new }

  before do
    @old_dir = Dir.pwd
    @old_tracker_api_token = ENV.fetch('TRACKER_API_TOKEN', nil)
    @old_tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID', nil)
    @old_tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID', nil)

    ENV.store('TRACKER_API_TOKEN', 'does not matter')
    ENV.store('TRACKER_PROJECT_ID', 'does not matter')
    ENV.store('TRACKER_REQUESTER_ID', 'does not matter')

    FileUtils.mkdir_p(File.join(root_dir, 'public-buildpacks-ci-robots', 'bosh-deployment-components'))
    File.write(concourse_known_versions_file, concourse_known_versions.to_yaml)
    File.write(gcp_cpi_known_versions_file, gcp_cpi_known_versions.to_yaml)

    FileUtils.mkdir_p(File.join(root_dir, 'concourse'))
    FileUtils.mkdir_p(File.join(root_dir, 'gcp-cpi'))
    File.write(File.join(root_dir, 'concourse', 'version'), '1.1')
    File.write(File.join(root_dir, 'gcp-cpi', 'version'), '2.2')

    allow(subject).to receive(:puts)
    allow(subject).to receive(:components).and_return components

    allow(GitClient).to receive(:add_file)
    allow(GitClient).to receive(:safe_commit)

    allow(TrackerApi::Client).to receive(:new).and_return tracker_client
    allow(TrackerApi::Client).to receive(:project).and_return buildpack_project

    Dir.chdir(root_dir)
  end

  after do
    Dir.chdir(@old_dir)
    ENV.store('TRACKER_API_TOKEN', @old_tracker_api_token)
    ENV.store('TRACKER_PROJECT_ID', @old_tracker_project_id)
    ENV.store('TRACKER_REQUESTER_ID', @old_tracker_requester_id)

    FileUtils.rm_rf(root_dir)
  end

  context 'the component is up-to-date' do
    it 'writes the fact to stdout' do
      subject.run!

      expect(subject).to have_received(:puts).with "The following are up-to-date:"
      expect(subject).to have_received(:puts).with "- Concourse"
    end

    it 'should only create story for out-of-date components' do
      subject.run!

      expect(buildpack_project).to have_received(:create_story).once
      expect(buildpack_project).to have_received(:create_story).with(hash_including(name: 'Update BOSH Google CPI for Concourse deployment'))
    end

    it 'does not update the YAML files' do
      subject.run!

      expect(YAML.load_file(concourse_known_versions_file)).to eq %w(1.1)
      expect(GitClient).not_to have_received(:add_file).with(File.join('bosh-deployment-components', 'concourse-versions.yml'))
      expect(GitClient).not_to have_received(:safe_commit).with('Detected new version of Concourse: 1.1')
    end
  end

  context 'the component is not up-to-date' do
    it 'writes the the new version to stdout' do
      subject.run!

      expect(subject).to have_received(:puts).with "*** New versions detected ***"
      expect(subject).to have_received(:puts).with "- BOSH Google CPI => 2.2"
    end

    context 'makes a Tracker story' do
      let(:concourse_known_versions)      { %w(1.0) }

      it 'adds content' do
        subject.run!

        expect(buildpack_project).to have_received(:create_story).with(hash_including(name: 'Update BOSH Google CPI for Concourse deployment', labels: ['concourse']))
      end

      it 'adds extra context to the Tracker story if the component is Concourse' do
        subject.run!

        expect(buildpack_project).to have_received(:create_story).with(hash_including(name: 'Update Concourse for Concourse deployment', labels: ['concourse'], description: /.*Run the \`bin\/deploy_concourse\` script from root\n1. git push when satisfied$/))
      end
    end

    it 'updates the YAML files' do
      subject.run!

      expect(YAML.load_file(gcp_cpi_known_versions_file)).to eq %w(1.1 2.2)
      expect(GitClient).to have_received(:add_file).with(File.join('bosh-deployment-components', 'gcp-cpi-versions.yml'))
      expect(GitClient).to have_received(:safe_commit).with('Detected new version of BOSH Google CPI: 2.2')
    end
  end
end
