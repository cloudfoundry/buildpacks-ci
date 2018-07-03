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
    allow(Octokit).to receive(:releases).and_return([])
    allow_any_instance_of(described_class).to receive(:open).with(/openjdk/).and_return(double(read: {}.to_yaml))
    allow_any_instance_of(described_class).to receive(:open).with('https://apr.apache.org/download.cgi').and_return(double(read: '<html></html>'))
    allow_any_instance_of(described_class).to receive(:open).with('https://maven.apache.org/docs/history.html').and_return(double(read: '<html>3.3.6 3.3.7 3.3.8 3.3.9</html>'))

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:write).and_call_original

    @old_github_username = ENV.fetch('GITHUB_USERNAME', nil)
    @old_github_password = ENV.fetch('GITHUB_PASSWORD', nil)
    @old_buildpacks_slack_webhook = ENV.fetch('BUILDPACKS_SLACK_WEBHOOK', nil)
    @old_tracker_api_token = ENV.fetch('TRACKER_API_TOKEN', nil)
    @old_tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID', nil)
    @old_capi_slack_webhook = ENV.fetch('CAPI_SLACK_WEBHOOK', nil)

    ENV.store('GITHUB_USERNAME', github_username)
    ENV.store('GITHUB_PASSWORD', github_password)
    ENV.store('BUILDPACKS_SLACK_WEBHOOK', 'does not matter')
    ENV.store('TRACKER_API_TOKEN', 'does not matter')
    ENV.store('TRACKER_REQUESTER_ID', 'does not matter')
    ENV.store('CAPI_SLACK_WEBHOOK', 'does not matter')
  end

  after do
    ENV.store('GITHUB_USERNAME', @old_github_username)
    ENV.store('GITHUB_PASSWORD', @old_github_password)
    ENV.store('BUILDPACKS_SLACK_WEBHOOK', @old_buildpacks_slack_webhook)
    ENV.store('TRACKER_API_TOKEN', @old_tracker_api_token)
    ENV.store('TRACKER_REQUESTER_ID', @old_tracker_requester_id)
    ENV.store('CAPI_SLACK_WEBHOOK', @old_capi_slack_webhook)
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
      elsif dependency_source == :github_releases
        allow(Octokit).to receive(:releases).with(github_repo).and_return(github_response)
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
      elsif dependency_source == :github_releases
        allow(Octokit).to receive(:releases).with(github_repo).and_return(github_response)
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

    context 'for apr' do
      let(:dependency)          { :apr }
      let(:old_versions)        { %w(1.6.0) }
      let(:new_versions)        { %w(1.6.1) }
      let(:new_releases_source) { 'https://apr.apache.org/download.cgi' }

      context 'when there are new releases' do
        let(:new_releases_response) { '<table>
          <tr><td><a name="other"><strong>APR-util 2.3.5 is the best available version</strong></a></td></tr>
          <tr><td><a name="apr1"><strong>APR 1.6.1 is the best available version</strong></a></td></tr>
          </table>' }

        it_behaves_like 'there are new versions to potentially build' do
          let(:all_versions) { new_versions }
        end
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { '<table>
          <tr><td><a name="other"><strong>APR-util 2.3.4 is the best available version</strong></a></td></tr>
          <tr><td><a name="apr1"><strong>APR 1.6.0 is the best available version</strong></a></td></tr>
          </table>' }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for apr-util' do
      let(:dependency)          { :apr_util }
      let(:old_versions)        { %w(2.3.4) }
      let(:new_versions)        { %w(2.3.5) }
      let(:new_releases_source) { 'https://apr.apache.org/download.cgi' }

      context 'when there are new releases' do
        let(:new_releases_response) { '<table>
          <tr><td><a name="other"><strong>APR 1.6.1 is the best available version</strong></a></td></tr>
          <tr><td><a name="aprutil1"><strong>APR-util 2.3.5 is the best available version</strong></a></td></tr>
          </table>' }

        it_behaves_like 'there are new versions to potentially build' do
          let(:all_versions) { new_versions }
        end
      end

      context 'when there are no new releases' do
        let(:new_releases_response) { '<table>
          <tr><td><a name="other"><strong>APR 1.6.0 is the best available version</strong></a></td></tr>
          <tr><td><a name="aprutil1"><strong>APR-util 2.3.4 is the best available version</strong></a></td></tr>
          </table>' }

        it_behaves_like 'there are no new versions to potentially build'
      end
    end

    context 'for maven' do
      let(:dependency)   { :maven }
      let(:old_versions) { %w(3.3.7 3.3.8) }
      let(:github_repo)  { 'apache/maven' }

      context 'when there are new releases' do
        let(:new_versions)          { %w(3.3.9) }
        let(:github_response) { [double(name: 'maven-3.3.7'), double(name: 'maven-3.3.8'), double(name: 'maven-3.3.9')] }

        it_behaves_like 'there are new versions to potentially build', :github
      end

      context 'when there are no new releases' do
        let(:github_response) { [double(name: 'maven-3.3.7'), double(name: 'maven-3.3.8')] }

        it_behaves_like 'there are no new versions to potentially build', :github
      end

      context 'github releases NOT on maven website are ignored' do
        let(:github_response) { [double(name: 'maven-3.3.5'), double(name: 'maven-3.3.7'), double(name: 'maven-3.3.8')] }

        it_behaves_like 'there are no new versions to potentially build', :github
      end
    end
  end

  describe '#post_to_slack' do
    let(:buildpacks_slack_client)   { double(:buildpacks_slack_client) }
    let(:capi_slack_client)         { double(:capi_slack_client) }

    before do
      @old_buildpacks_channel = ENV.fetch('BUILDPACKS_SLACK_CHANNEL', nil)
      @old_capi_channel = ENV.fetch('CAPI_SLACK_CHANNEL', nil)

      @old_buildpacks_webhook = ENV.fetch('BUILDPACKS_SLACK_WEBHOOK', nil)
      @old_capi_webhook = ENV.fetch('CAPI_SLACK_WEBHOOK', nil)

      ENV.store('BUILDPACKS_SLACK_CHANNEL', '#buildpacks')
      ENV.store('CAPI_SLACK_CHANNEL', '#capi')

      ENV.store('BUILDPACKS_SLACK_WEBHOOK', 'some-webhook')
      ENV.store('CAPI_SLACK_WEBHOOK', 'some-webhook')

      allow(SlackClient).to receive(:new).with(anything, '#buildpacks', anything).and_return(buildpacks_slack_client)
      allow(SlackClient).to receive(:new).with(anything, '#capi', anything).and_return(capi_slack_client)

      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return([changed_dependencies, current_tags, unchanged_dependencies])
    end

    after do
      ENV.store('BUILDPACKS_SLACK_CHANNEL', @old_buildpacks_channel)
      ENV.store('CAPI_SLACK_CHANNEL', @old_capi_channel)

      ENV.store('BUILDPACKS_SLACK_WEBHOOK', @old_buildpacks_webhook)
      ENV.store('CAPI_SLACK_WEBHOOK', @old_capi_webhook)
    end

    context 'with new versions for a dependency' do
      let(:changed_dependencies) { {apr: %w(a b) } }

      it 'posts to buildpacks slack for each new release of that dependency' do
        expect(buildpacks_slack_client).to receive(:post_to_slack).with("There is a new version of *apr* available: *a, b*")
        expect(capi_slack_client).to_not receive(:post_to_slack)
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
      @old_buildpacks_env = ENV.fetch('BUILDPACKS_TRACKER_PROJECT_ID', nil)
      @old_capi_env = ENV.fetch('CAPI_TRACKER_PROJECT_ID', nil)

      ENV.store('BUILDPACKS_TRACKER_PROJECT_ID', 'buildpacks-project-id')
      ENV.store('CAPI_TRACKER_PROJECT_ID', 'capi-project-id')

      allow(TrackerClient).to receive(:new).with(anything, 'buildpacks-project-id', anything).and_return(buildpacks_tracker_client)
      allow(TrackerClient).to receive(:new).with(anything, 'capi-project-id', anything).and_return(capi_tracker_client)

      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return([changed_dependencies, current_tags, unchanged_dependencies])

      allow(BuildpackDependency).to receive(:for).with(dependency).and_return(buildpack_dependency_tasks)
    end

    context 'with new versions for a dependency' do
      let(:dependency) { :apr }
      let(:changed_dependencies) { {apr: %w(a b) } }

      it 'posts a tracker story with the dependency and versions in the story title' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(name: 'Build and/or Include new releases: apr a, b',
               description: anything, tasks: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story with the dependency and versions in the story description' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(description: "We have 2 new releases for **apr**:\n**version a, b**\n\nThis dependency is NOT handled by the binary-builder-new pipeline.\nUpdate the httpd recipe in the binary-builder repo.",
               name: anything, tasks: anything, point_value: anything, labels: anything)

        expect(capi_tracker_client).not_to receive(:post_to_tracker)

        subject.post_to_tracker
      end

      it 'posts a tracker story with tasks to update the dependency in buildpacks' do
        expect(buildpacks_tracker_client).to receive(:post_to_tracker).
          with(tasks: ['Verify apr is updated in snake-buildpack if version is supported', 'Verify apr is updated in lizard-buildpack if version is supported'],
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

    context 'with no new versions for a dependency' do
      let(:dependency) { :apr }
      let(:changed_dependencies) { {} }

      it 'posts to slack for each new release of that dependency' do
        expect(buildpacks_tracker_client).to_not receive(:post_to_tracker)
        expect(capi_tracker_client).not_to receive(:post_to_tracker)
        subject.post_to_tracker
      end
    end
  end
end
