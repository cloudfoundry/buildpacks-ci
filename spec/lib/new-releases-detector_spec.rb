# encoding: utf-8
require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/new-releases-detector'
require_relative '../../lib/buildpack-dependency'

describe NewReleasesDetector do
  def to_tags(names)
    names.collect { |n| OpenStruct.new(name: n) }
  end

  let(:new_releases_dir) { Dir.mktmpdir }
  let(:github_username)  { 'github_username' }
  let(:github_password)  { 'github_password1!' }

  before do
    allow_any_instance_of(described_class).to receive(:warn) {}
    allow(Octokit).to receive(:configure)
    allow(Octokit).to receive(:tags).and_return([])
    allow_any_instance_of(described_class).to receive(:open).with(/python/).and_return(double(read: { 'tags' => [] }.to_json))
    allow_any_instance_of(described_class).to receive(:open).with(/openjdk/).and_return(double(read: {}.to_yaml))
    allow_any_instance_of(described_class).to receive(:open).with(/node/).and_return(double(read: [].to_json))
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:write).and_call_original

    allow(ENV).to receive(:fetch).with('GITHUB_USERNAME').and_return(github_username)
    allow(ENV).to receive(:fetch).with('GITHUB_PASSWORD').and_return(github_password)
  end

  subject { described_class.new(new_releases_dir) }

  shared_examples_for 'there are new versions to potentially build' do
    let(:yaml_filename)     { "#{new_releases_dir}/#{dependency}.yaml"}
    let(:yaml_new_filename) { "#{new_releases_dir}/#{dependency}-new.yaml"}
    let(:all_versions)      { old_versions + new_versions }

    before do
      allow(File).to receive(:exist?).with(yaml_filename).and_return(true)
      allow(YAML).to receive(:load_file).with(yaml_filename).and_return(old_versions)
      allow_any_instance_of(described_class).to receive(:open)
        .with(new_releases_source)
        .and_return(new_releases_response)
    end

    it 'sets dependency_tags to a hash of dependencies as keys and array of diffs as values' do
      expect(subject.dependency_tags).to eq({dependency => new_versions})
    end

    it 'writes to a file the latest releases' do
      expect(File).to receive(:write).with(yaml_filename, all_versions.to_yaml)
      subject
    end

    it 'writes the diff in releases to a file' do
      expect(File).to receive(:write).with(yaml_new_filename, new_versions.to_yaml)
      subject
    end
  end

  shared_examples_for 'there are no new versions to potentially build' do
    let(:yaml_filename) { "#{new_releases_dir}/#{dependency}.yaml"}
    let(:new_versions)  { [] }

    before do
      allow_any_instance_of(described_class).to receive(:warn).and_call_original
      allow(File).to receive(:exist?).with(yaml_filename).and_return(true)
      allow(YAML).to receive(:load_file).with(yaml_filename).and_return(old_versions)
      allow_any_instance_of(described_class).to receive(:open)
        .with(new_releases_source)
        .and_return(new_releases_response)
    end

    it 'sets dependency_tags to an empty hash' do
      expect(subject.dependency_tags).to eq({})
    end

    it 'outputs to stderr that there are no new updates' do
      expect do
        subject
      end.to output(/There are no new updates to the \*#{dependency}\* dependency\n/).to_stderr
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
  end

  describe '#post_to_slack' do
    let(:slack_client) { double(:slack_client) }

    before do
      allow(SlackClient).to receive(:new).and_return(slack_client)
      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return(dependency_tags)
    end

    context 'with new versions for a dependency' do
      let(:dependency_tags) { { python: %w(a b) } }

      it 'posts to slack for each new release of that dependency' do
        expect(slack_client).to receive(:post_to_slack).with("There is a new update to the *python* dependency: version *a*\n")
        expect(slack_client).to receive(:post_to_slack).with("There is a new update to the *python* dependency: version *b*\n")
        subject.post_to_slack
      end
    end

    context 'with no new versions for a dependency' do
      let(:dependency_tags) { {} }

      it 'posts to slack for each new release of that dependency' do
        expect(slack_client).to_not receive(:post_to_slack)
        subject.post_to_slack
      end
    end
  end

  describe '#post_to_tracker' do
    let(:tracker_client)             { double(:tracker_client) }
    let(:buildpack_dependency_tasks) { [:snake, :lizard] }

    before do
      allow(TrackerClient).to receive(:new).and_return(tracker_client)
      allow_any_instance_of(described_class).to receive(:generate_dependency_tags).with(new_releases_dir).and_return(dependency_tags)

      allow(BuildpackDependency).to receive(:for).with(:python).and_return(buildpack_dependency_tasks)
    end

    context 'with new versions for a dependency' do
      let(:dependency_tags) { { python: %w(a b) } }

      it 'posts one story to tracker with all new releases of that dependency' do
        expect(tracker_client).to receive(:post_to_tracker).with(name: 'Build and/or Include new releases: python a, b',
                                                                 description: "We have 2 new releases for **python**:\n**version a, b**\n See the documentation at http://docs.cloudfoundry.org/buildpacks/upgrading_dependency_versions.html for info on building a new release binary and adding it to the buildpack manifest file.",
                                                                 tasks: ['Update python in snake-buildpack', 'Update python in lizard-buildpack'],
                                                                 point_value: 1)
        subject.post_to_tracker
      end
    end

    context 'with no new versions for a dependency' do
      let(:dependency_tags) { {} }

      it 'posts to slack for each new release of that dependency' do
        expect(tracker_client).to_not receive(:post_to_tracker)
        subject.post_to_tracker
      end
    end
  end
end
