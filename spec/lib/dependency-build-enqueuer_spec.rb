# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/dependency-build-enqueuer'
require_relative '../../lib/buildpack-dependency'
require 'yaml'
require 'tmpdir'

describe DependencyBuildEnqueuer do
  let(:new_releases_dir)    { Dir.mktmpdir }
  let(:binary_builds_dir)   { File.expand_path(File.join(File.dirname(__FILE__),'..','..')) }
  let(:options)             { {} }
  let(:test_branch_name)    { "dependency-build-enqueuer-test-#{(10000*(Random.rand)).to_i}" }

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
      `git checkout -b #{test_branch_name}`
    end

    after do
      `git checkout develop`
      `git branch -D #{test_branch_name}`
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
        allow(described_class).to receive(:shasum_256_verification).with("https://github.com/nodejs/node/archive/v5.7.8.tar.gz").and_return(["sha256", sha256])
        allow(described_class).to receive(:shasum_256_verification).with("https://github.com/nodejs/node/archive/v0.12.5.tar.gz").and_return(["sha256", sha256_1])

        File.open(dependency_new_versions_file, "w") do |file|
          file.write new_versions.to_yaml
        end

        subject.enqueue_build
      end


      context 'there are multiple versions submitted to be built' do
        it 'creates a commit for each version' do
          count_of_git_commits = `git log --oneline develop..#{test_branch_name} | wc -l`.to_i
          expect(count_of_git_commits).to eq 2
        end

        context 'for each distinct version' do
          let(:committed_dependency) { YAML.load_file(builds_file) }

          it 'has a single version number in a commit message' do
            commit_msg = `git log --oneline -1 HEAD`
            expect(commit_msg).to include '5.7.8'

            commit_msg = `git log --oneline -1 HEAD~`
            expect(commit_msg).to include '0.12.5'
          end

          it 'has a single version number in the node-builds.yml file' do
            expect(committed_dependency['node'].size).to eq 1
          end

          it 'has the version number in the node-builds.yml file' do
            expect(committed_dependency['node'][0]['version']).to eq '5.7.8'
          end

          it 'has the SHA256 in the node-builds.yml file' do
            expect(committed_dependency['node'][0]['sha256']).to eq sha256
          end
        end
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
