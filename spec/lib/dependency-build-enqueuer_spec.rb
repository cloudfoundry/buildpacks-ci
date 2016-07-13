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
    let(:dependency_versions_file)      { File.join(new_releases_dir, "#{dependency}.yaml") }
    let(:dependency_new_versions_file)  { File.join(new_releases_dir, "#{dependency}-new.yaml") }
    let(:builds_file)                   { File.join(binary_builds_dir, "#{dependency}-builds.yml") }
    let(:sha256)                        { "sha256-mocked" }
    let(:sha256_1)                      { "sha256-mocked-1" }

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
        allow(described_class).to receive(:build_verifications_for).with("godep", "v62").and_return([['sha256', sha256]])
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
        allow(described_class).to receive(:build_verifications_for).with("composer", "1.1.1").and_return([['sha256', sha256]])
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
        allow(described_class).to receive(:build_verifications_for).with("glide", "v0.10.3").and_return([['sha256', sha256]])
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

    context "nginx" do
      let(:dependency)          { "nginx" }
      let(:dependency_versions) { %w(release-1.5.8 release-1.4.1 release-1.11.2) }
      let(:dependency_builds)   { {nginx: [] } }

      before do
        allow(described_class).to receive(:build_verifications_for).with("nginx", "1.11.2").and_return([['gpg-rsa-key-id', 'gpg-key-mocked'], ['gpg-signature', 'gpg-signature-mocked']])
      end

      it "enqueues a build for the latest dep version in the correlated builds yml file" do
        subject.enqueue_build

        builds = YAML.load_file(builds_file)

        enqueued_builds = builds['nginx']
        expect(enqueued_builds.count).to eq(1)
        expect(enqueued_builds.first['version']).to eq("1.11.2")
        expect(enqueued_builds.first['gpg-rsa-key-id']).to eq("gpg-key-mocked")
        expect(enqueued_builds.first['gpg-signature']).to eq("gpg-signature-mocked")
      end
    end

    context "node" do
      let(:dependency)          { "node" }
      let(:dependency_versions) { %w(v4.5.6 v0.12.5 v6.6.9 v0.10.6 v5.7.8) }
      let(:new_versions)        { %w(v0.12.5 v5.7.8) }
      let(:dependency_builds)   { {node: [] } }

      before do
        File.open(dependency_new_versions_file, "w") do |file|
          file.write new_versions.to_yaml
        end
        allow(described_class).to receive(:shasum_256_verification).with("https://github.com/nodejs/node/archive/v5.7.8.tar.gz").and_return(["sha256", sha256])
        allow(described_class).to receive(:shasum_256_verification).with("https://github.com/nodejs/node/archive/v0.12.5.tar.gz").and_return(["sha256", sha256_1])
      end

      it "enqueues a build for the all versions in the correlated builds-new yml file" do
        subject.enqueue_build

        builds = YAML.load_file(builds_file)

        enqueued_builds = builds['node']
        expect(enqueued_builds.count).to eq(2)
        expect(enqueued_builds).to include({"version" =>"0.12.5", "sha256" => sha256_1})
        expect(enqueued_builds).to include({"version" =>"5.7.8", "sha256" => sha256})
      end
    end
  end

  describe '#latest_version_for_dependency' do
    subject { described_class.latest_version_for_dependency(dependency, dependency_versions, options) }

    context "godep" do
      let(:dependency)          { "godep" }
      let(:dependency_versions) { %w(v60 v61 v62 v102) }

      it 'returns the latest godep version in the passed versions' do
        expect(subject).to eq("v102")
      end
    end

    context "composer" do
      let(:dependency)          { "composer" }
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
      let(:dependency)          { "glide" }
      let(:dependency_versions) { %w(v0.9.2 v0.10.0 v0.10.3) }

      it 'returns the latest glide version in the passed versions' do
        expect(subject).to eq("v0.10.3")
      end
    end

    context "nginx" do
      let(:dependency)          { "nginx" }
      let(:dependency_versions) { %w(release-1.5.8 release-1.4.1 release-1.11.2) }

      it 'returns the latest nginx version in the passed versions' do
        expect(subject).to eq("1.11.2")
      end
    end
  end
end
