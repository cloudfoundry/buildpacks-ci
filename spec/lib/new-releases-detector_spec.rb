# encoding: utf-8
require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/new-releases-detector'
require_relative '../../lib/buildpack-dependency'

describe NewReleasesDetector do
  def to_tags(names)
    names.collect { |n| OpenStruct.new(name: n) }
  end

  let(:current_tags) { {} }
  let(:unchanged_dependencies) { [] }
  let(:new_releases_dir) { Dir.mktmpdir }
  let(:github_username)  { 'github_username' }
  let(:github_password)  { 'github_password1!' }
  let(:github_repo)      { 'default' }

  before do
    allow_any_instance_of(described_class).to receive(:warn) {}
    allow(Octokit).to receive(:configure)
    allow(Octokit).to receive(:tags).and_return([])
    allow(Git).to receive(:ls_remote).with('http://git.savannah.gnu.org/cgit/libunwind.git').and_return({'tags' => {}})
    allow_any_instance_of(described_class).to receive(:open).with(/python/).and_return(double(read: { 'tags' => [] }.to_json))
    allow_any_instance_of(described_class).to receive(:open).with(/openjdk/).and_return(double(read: {}.to_yaml))
    allow_any_instance_of(described_class).to receive(:open).with(/node/).and_return(double(read: [].to_json))
    allow_any_instance_of(described_class).to receive(:open).with(/bower/).and_return(double(read: { 'versions' => {} }.to_json))
    allow_any_instance_of(described_class).to receive(:open).with(/miniconda/).and_return(double(read: '<html></html>'))

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:write).and_call_original

    allow(ENV).to receive(:fetch).with('GITHUB_USERNAME').and_return(github_username)
    allow(ENV).to receive(:fetch).with('GITHUB_PASSWORD').and_return(github_password)
  end

  subject { described_class.new(new_releases_dir) }

  shared_examples_for 'there are new versions to potentially build'  do |dependency_source|
    let(:yaml_filename)     { "#{new_releases_dir}/#{dependency}.yml"}
    let(:yaml_new_filename) { "#{new_releases_dir}/#{dependency}-new.yml"}
    let(:all_versions)      { old_versions + new_versions }

    before do
      allow_any_instance_of(described_class).to receive(:warn).and_call_original
      allow(File).to receive(:exist?).with(yaml_filename).and_return(true)
      allow(YAML).to receive(:load_file).with(yaml_filename).and_return(old_versions)

      if dependency_source == :github
        allow(Octokit).to receive(:tags).with(github_repo).and_return(github_response)
      else
        allow_any_instance_of(described_class).to receive(:open)
          .with(new_releases_source)
          .and_return(new_releases_response)
      end
    end

    it 'sets dependency_tags to a hash of dependencies as keys and array of diffs as values' do
      expect(subject.changed_dependencies).to eq({dependency => new_versions})
    end

    it 'writes to a file the latest releases' do
      expect(File).to receive(:write).with(yaml_filename, all_versions.to_yaml)
      subject
    end

    it 'writes the diff in releases to a file' do
      expect(File).to receive(:write).with(yaml_new_filename, new_versions.to_yaml)
      subject
    end

    it 'outputs to stderr that there are new updates' do
      expect { subject }.
        to output(/NEW DEPENDENCIES FOUND:\n\n^- #{dependency}:/).to_stderr
      end
  end

  shared_examples_for 'there are no new versions to potentially build' do |dependency_source|
    let(:yaml_filename) { "#{new_releases_dir}/#{dependency}.yml"}
    let(:new_versions)  { [] }

    before do
      allow_any_instance_of(described_class).to receive(:warn).and_call_original
      allow(File).to receive(:exist?).with(yaml_filename).and_return(true)
      allow(YAML).to receive(:load_file).with(yaml_filename).and_return(old_versions)

      if dependency_source == :github
        allow(Octokit).to receive(:tags).with(github_repo).and_return(github_response)
      else
        allow_any_instance_of(described_class).to receive(:open)
          .with(new_releases_source)
          .and_return(new_releases_response)
      end
    end

    it 'sets dependency_tags to an empty hash' do
      expect(subject.changed_dependencies).to eq({})
    end

    it 'outputs to stderr that there are no new updates' do
      expect { subject }.to output(/No Updates Needed:(.*)^- #{dependency}/m).to_stderr
    end
  end

  describe '#initialize' do
    it 'sets new_releases_dir' do
      expect(subject.new_releases_dir).to eq(new_releases_dir)
    end

    context 'configures Octokit' do
      it 'sets the autopaginate to true' do
        expect(Octokit).to receive(:auto_paginate=).with(true).at_least(:once)
        subject
      end
    end

    context 'for openjdk' do
      let(:dependency)          { :openjdk }
      let(:old_versions)        { %w(v1 v2) }
      let(:new_releases_source) { 'https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(v3 v4) }
        let(:new_releases_response) { double(read: { 'v1' => 1, 'v2' => 2, 'v3' => 3, 'v4' => 4 }.to_yaml) }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { double(read: { 'v1' => 1, 'v2' => 2 }.to_yaml) }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for python' do
      let(:dependency)          { :python }
      let(:old_versions)        { %w(a b) }
      let(:new_versions)        { %w(c) }
      let(:new_releases_source) { 'https://hg.python.org/cpython/json-tags' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(c) }
        let(:new_releases_response) { double(read: { tags: [{ tag: 'a' }, { tag: 'b' }, { tag: 'c' }] }.to_json) }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { double(read: { tags: [{ tag: 'a' }, { tag: 'b' }] }.to_json) }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for node' do
      let(:dependency)          { :node }
      let(:old_versions)        { %w(1.2.3 1.2.4) }
      let(:new_releases_source) { 'https://nodejs.org/dist/index.json' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(1.2.5) }
        let(:new_releases_response) { double(read: [{ 'version' => 'v1.2.3'}, { 'version' => 'v1.2.4'}, { 'version' => 'v1.2.5'}].to_json) }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { double(read: [{ 'version' => 'v1.2.3'}, { 'version' => 'v1.2.4'}].to_json) }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for nginx' do
      let(:dependency)   { :nginx }
      let(:old_versions) { %w(1.10.1 1.10.2) }
      let(:github_repo)  { 'nginx/nginx' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(1.10.5) }
        let(:github_response) { [double(name: 'release-1.10.1'), double(name: 'release-1.10.2'), double(name: 'release-1.10.5')] }

        it_behaves_like 'there are new versions to potentially build', :github
      end

      context 'when there are no new releases' do
        let(:github_response) { [double(name: 'release-1.10.1'), double(name: 'release-1.10.2')] }

        it_behaves_like 'there are no new versions to potentially build', :github
      end
    end

    context 'for bower' do
      let(:dependency)          { :bower }
      let(:old_versions)        { %w(1.7.6 1.7.7) }
      let(:new_releases_source) { 'https://registry.npmjs.org/bower' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(1.7.9) }
        let(:new_releases_response) { double(read: { 'versions' => { '1.7.6': 'data', '1.7.7': 'data', '1.7.9': 'data' } }.to_json) }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { double(read: { 'versions' => { '1.7.6': 'data', '1.7.7': 'data' } }.to_json) }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for miniconda' do
      let(:dependency)   { :miniconda }
      let(:old_versions) { %w(3.33.33 4.44.44) }
      let(:new_releases_source) { 'https://repo.continuum.io/miniconda/' }

      context 'when there are new releases' do
        let(:new_versions)            { %w(5.55.55) }
        let(:new_releases_response)   { double('new_releases_response', read: miniconda_releases_html ) }
        let(:miniconda_releases_html) { <<~HTML
                                        <table>
                                          <tr>
                                            <td>
                                              <a href="http://example.com/Miniconda2-4.44.44-Linux-x86_64.sh">Miniconda2-5.55.55-Linux-x86_64.sh</a>
                                            </td>
                                          </tr>
                                          <tr>
                                            <td>
                                              <a href="http://example.com/Miniconda2-3.33.33-Linux-x86_64.sh">Miniconda99-4.44.44-Linux-x86_64.sh</a>
                                            </td>
                                          </tr>
                                          <tr>
                                            <td>
                                              <a href="http://example.com/Miniconda2-5.55.55-Linux-x86_64.sh">Miniconda2-3.33.33-Linux-x86_64.sh</a>
                                            </td>
                                          </tr>
                                        </table>
                                      HTML
        }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response)   { double('new_releases_response', read: miniconda_releases_html ) }
        let(:miniconda_releases_html) { <<~HTML
                                        <table>
                                          <tr>
                                            <td>
                                              <a href="http://example.com/Miniconda2-4.44.44-Linux-x86_64.sh">Miniconda2-5.55.55-Linux-x86_64.sh</a>
                                            </td>
                                          </tr>
                                          <tr>
                                            <td>
                                              <a href="http://example.com/Miniconda2-3.33.33-Linux-x86_64.sh">Miniconda99-4.44.44-Linux-x86_64.sh</a>
                                            </td>
                                          </tr>
                                        </table>
        HTML
        }


        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for libunwind' do
      let(:dependency)          { :libunwind }
      let(:old_versions)        { %w(1.0 1.1) }
      let(:new_releases_source) { 'http://git.savannah.gnu.org/cgit/libunwind.git' }

      before do
        allow(Git).to receive(:ls_remote).
          with('http://git.savannah.gnu.org/cgit/libunwind.git').
          and_return(new_releases_response)
      end

      context 'when there are new releases' do
        let(:new_versions)          { %w(1.2 1.2-rc3) }
        let(:new_releases_response) { { 'tags' => { '1.0' => {}, '1.1' => {}, '1.2' => {}, '1.2-rc3' => {} } } }

        it_behaves_like 'there are new versions to potentially build'
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { { 'tags' => { '1.0' => {}, '1.1' => {} } } }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end
  end

  describe '#post_to_slack' do
    let(:buildpacks_slack_client) { double(:buildpacks_slack_client) }
    let(:capi_slack_client)       { double(:capi_slack_client) }

    before do
      @old_buildpacks_env = ENV['BUILDPACKS_SLACK_WEBHOOK']
      @old_capi_env = ENV['CAPI_SLACK_CHANNEL']

      ENV['BUILDPACKS_SLACK_CHANNEL'] = '#buildpacks'
      ENV['CAPI_SLACK_CHANNEL'] = '#capi'

      allow(SlackClient).to receive(:new).with(anything, '#buildpacks', anything).and_return(buildpacks_slack_client)
      allow(SlackClient).to receive(:new).with(anything, '#capi', anything).and_return(capi_slack_client)

      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return([changed_dependencies, current_tags, unchanged_dependencies])
    end

    after do
      ENV['BUILDPACKS_SLACK_CHANNEL'] = @old_buildpacks_env
      ENV['CAPI_SLACK_CHANNEL'] = @old_capi_env
    end

    context 'with new versions for a dependency' do
      let(:changed_dependencies) { {python: %w(a b) } }

      it 'posts to buildpacks slack for each new release of that dependency' do
        expect(buildpacks_slack_client).to receive(:post_to_slack).with("There is a new update to the *python* dependency: version *a*\n")
        expect(buildpacks_slack_client).to receive(:post_to_slack).with("There is a new update to the *python* dependency: version *b*\n")
        expect(capi_slack_client).to_not receive(:post_to_slack)
        subject.post_to_slack
      end
    end

    context 'with new versions of nginx' do
      let(:changed_dependencies) { {nginx: %w(23.45.67) } }

      it 'posts to buildpacks slack for each new release of that dependency' do
        expect(buildpacks_slack_client).to receive(:post_to_slack).with("There is a new update to the *nginx* dependency: version *23.45.67*\n")
        expect(capi_slack_client).to receive(:post_to_slack).with("There is a new version of *nginx* available: 23.45.67")
        subject.post_to_slack
      end
    end

    context 'with no new versions for a dependency' do
      let(:changed_dependencies) { {} }

      it 'does not post to slack' do
        expect(buildpacks_slack_client).to_not receive(:post_to_slack)
        expect(capi_slack_client).to_not receive(:post_to_slack)
        subject.post_to_slack
      end
    end
  end

  describe '#post_to_tracker' do
    let(:buildpacks_tracker_client) { double(:buildpacks_tracker_client) }
    let(:capi_tracker_client)       { double(:capi_tracker_client) }
    let(:buildpack_dependency_tasks) { [:snake, :lizard] }

    before do
      @old_buildpacks_env = ENV['BUILDPACKS_TRACKER_PROJECT_ID']
      @old_capi_env = ENV['CAPI_TRACKER_PROJECT_ID']

      ENV['BUILDPACKS_TRACKER_PROJECT_ID'] = 'buildpacks-project-id'
      ENV['CAPI_TRACKER_PROJECT_ID'] = 'capi-project-id'

      allow(TrackerClient).to receive(:new).with(anything, 'buildpacks-project-id', anything).and_return(buildpacks_tracker_client)
      allow(TrackerClient).to receive(:new).with(anything, 'capi-project-id', anything).and_return(capi_tracker_client)

      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return([changed_dependencies, current_tags, unchanged_dependencies])

      allow(BuildpackDependency).to receive(:for).with(dependency).and_return(buildpack_dependency_tasks)
    end

    context 'with new versions for a dependency' do
      let(:dependency) { :python }
      let(:changed_dependencies) { {python: %w(a b) } }

      it 'posts a tracker story with the dependency and versions in the story title' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(name: 'Build and/or Include new releases: python a, b',
               description: anything, tasks: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story with the dependency and versions in the story description' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(description: "We have 2 new releases for **python**:\n**version a, b**\n See the documentation at http://docs.cloudfoundry.org/buildpacks/upgrading_dependency_versions.html for info on building a new release binary and adding it to the buildpack manifest file.",
               name: anything, tasks: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story with tasks to update the dependency in buildpacks' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(tasks: ['Update python in snake-buildpack', 'Update python in lizard-buildpack'],
               name: anything, description: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story worth 1 story point' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(point_value: 1,
               name: anything, description: anything, tasks: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story with the buildpack names as labels' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(labels: %w(snake lizard),
               name: anything, description: anything, tasks: anything, point_value: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end
    end

    context 'with new versions for a dependency' do
      let(:dependency) { :nginx }
      let(:changed_dependencies) { {nginx: %w(11.11.11) } }

      it 'posts a tracker story to the CAPI project with the correct information' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(name: anything, description: anything, tasks: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).to receive(:post_to_tracker).
          with(name: 'New version(s) of nginx: 11.11.11',
               description: 'There are 1 new version(s) of **nginx** available: 11.11.11',
               tasks: [],
               point_value: 1,
               labels: []
              )

        subject.post_to_tracker
      end
    end

    context 'there are new versions of dotnet' do
      let(:dependency) { :dotnet }
      let(:buildpack_dependency_tasks) { [:microsoft] }
      let(:changed_dependencies) { {dotnet: %w(1.0.0-preview43) } }

      it 'adds a task to the tracker story to remove non-MS supported versions of dotnet' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(tasks: ['Update dotnet in microsoft-buildpack', 'Remove any dotnet versions MS no longer supports'],
               name: anything, description: anything, point_value: anything, labels: anything
        )

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end
    end

    context 'with no new versions for a dependency' do
      let(:dependency) { :python }
      let(:changed_dependencies) { {} }

      it 'posts to slack for each new release of that dependency' do
        expect(buildpacks_tracker_client).to_not receive(:post_to_tracker)
        expect(capi_tracker_client).not_to receive(:post_to_tracker)
        subject.post_to_tracker
      end
    end
  end
end
