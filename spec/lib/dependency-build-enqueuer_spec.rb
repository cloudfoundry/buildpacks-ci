# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/dependency-build-enqueuer'
require_relative '../../lib/buildpack-dependency'
require 'yaml'

describe DependencyBuildEnqueuer do
  let(:new_releases_dir)         { Dir.mktmpdir }
  let(:binary_builds_dir)        { Dir.mktmpdir }
  let(:options)                  { {} }

  subject { described_class.new(dependency, new_releases_dir, binary_builds_dir, options) }

  describe '#enqueue_build' do
    let(:dependency_versions_file) { File.join(new_releases_dir, "#{dependency}.yaml") }
    let(:builds_file)              { File.join(binary_builds_dir, "#{dependency}-builds.yml") }
    let(:sha256)                   { "sha256-mocked" }

    before do
      File.open(dependency_versions_file, "w") do |file|
        file.write dependency_versions.to_yaml
      end
      File.open(builds_file, "w") do |file|
        file.write dependency_builds.to_yaml
      end
    end

    context "godep" do
      let(:dependency)          { "godep" }
      let(:dependency_versions) { %w(v60 v61 v62) }
      let(:dependency_builds)   { {godep: [] } }

      before do
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

    context "composer" do
      let(:dependency)          { "composer" }
      let(:dependency_versions) { %w(1.1.0-RC 1.0.3 1.1.1 1.1.1-alpha1) }
      let(:dependency_builds)   { {composer: [] } }

      before do
        allow(described_class).to receive(:build_verification_for).with("composer", "1.1.1").and_return(['sha256', sha256])
      end

      it "enqueues a build for the latest dep version in the correlated builds yml file" do
        subject.enqueue_build

        builds = YAML.load_file(builds_file)
        enqueued_builds = builds['composer']
        expect(enqueued_builds.count).to eq(1)
        expect(enqueued_builds.first['version']).to eq("1.1.1")
        expect(enqueued_builds.first['sha256']).to eq("sha256-mocked")
      end
    end

    context "glide" do
      let(:dependency)          { "glide" }
      let(:dependency_versions) { %w(v0.9.2 v0.10.0 v0.10.3) }
      let(:dependency_builds)   { {glide: [] } }

      before do
        allow(described_class).to receive(:build_verification_for).with("glide", "v0.10.3").and_return(['sha256', sha256])
      end

      it "enqueues a build for the latest dep version in the correlated builds yml file" do
        subject.enqueue_build

        builds = YAML.load_file(builds_file)
        enqueued_builds = builds['glide']
        expect(enqueued_builds.count).to eq(1)
        expect(enqueued_builds.first['version']).to eq("v0.10.3")
        expect(enqueued_builds.first['sha256']).to eq("sha256-mocked")
      end
    end
  end

  describe '#latest_version_for_dependency' do
    subject { described_class.latest_version_for_dependency(dependency, dependency_versions, options) }

    context "godep" do
      let(:dependency)               { "godep" }
      let(:dependency_versions) { %w(v60 v61 v62 v102) }

      it 'returns the latest godep version in the passed versions' do
        expect(subject).to eq("v102")
      end
    end

    context "composer" do
      let(:dependency)               { "composer" }
      let(:dependency_versions) { %w(1.1.0-RC 1.0.3 1.1.1 1.2.0-RC) }

      it 'returns the latest composer version in the passed versions' do
        expect(subject).to eq("1.1.1")
      end

      context "pre-releases allowed to build" do
        let(:options) { { pre: true } }

        it 'returns the latest composer version in the passed versions' do
          expect(subject).to eq("1.2.0-RC")
        end
      end
    end

    context "glide" do
      let(:dependency)               { "glide" }
      let(:dependency_versions) { %w(v0.9.2 v0.10.0 v0.10.3) }

      it 'returns the latest glide version in the passed versions' do
        expect(subject).to eq("v0.10.3")
      end
    end
  end
end
