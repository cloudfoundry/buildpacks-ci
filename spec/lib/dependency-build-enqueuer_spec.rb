# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/dependency-build-enqueuer'
require_relative '../../lib/buildpack-dependency'
require 'yaml'

describe DependencyBuildEnqueuer do
  let(:dependency)               { "godep" }
  let(:new_releases_dir)         { Dir.mktmpdir }
  let(:binary_builds_dir)        { Dir.mktmpdir }

  subject { described_class.new(dependency, new_releases_dir, binary_builds_dir) }

  describe '#enqueue_build' do
    let(:dependency_versions_file) { File.join(new_releases_dir, "#{dependency}.yaml") }
    let(:builds_file)              { File.join(binary_builds_dir, "#{dependency}-builds.yml") }
    let(:sha256)                   { "sha256-mocked" }

    before do
      godep_versions = %w(v60 v61 v62)
      File.open(dependency_versions_file, "w") do |file|
        file.write godep_versions.to_yaml
      end
      godep_builds = {godep: []}
      File.open(builds_file, "w") do |file|
        file.write godep_builds.to_yaml
      end
      allow(described_class).to receive(:build_verification_for).with("godep", "v62").and_return(['sha256', sha256])
    end

    it "enqueues a build for the latest dep version in the correlated builds yml file" do
      subject.enqueue_build

      builds = YAML.load_file(builds_file)
      enqueued_builds = builds['godep']
      expect(enqueued_builds.count).to eq(1)
      expect(enqueued_builds.first['version']).to eq("v62")
      expect(enqueued_builds.first['sha256']).to eq("sha256-mocked")
    end
  end

  describe '#latest_version_for_dependency' do
    context "godep" do
      let(:dependency_versions) { %w(v60 v61 v62 v102) }

      it 'returns the latest godep version in the passed versions' do
        latest_version = described_class.latest_version_for_dependency(dependency, dependency_versions)

        expect(latest_version).to eq("v102")
      end
    end
  end
end
