# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/dependency-build-enqueuer'
require_relative '../../lib/buildpack-dependency'
require_relative '../../lib/git-client'
require 'yaml'
require 'tmpdir'
require 'webmock/rspec'

describe DependencyBuildEnqueuer do
  let(:new_releases_dir)    { Dir.mktmpdir }
  let(:binary_builds_dir)   { Dir.mktmpdir }
  let(:options)             { {} }
  let(:test_branch_name)    { "dependency-build-enqueuer-test-#{(10000*(Random.rand)).to_i}" }

  subject { described_class.new(dependency, new_releases_dir, binary_builds_dir, options) }

  describe '#enqueue_build' do
    let(:dependency_new_versions_file)  { File.join(new_releases_dir, "#{dependency}-new.yaml") }
    let(:builds_file)                   { File.join(binary_builds_dir, "#{dependency}-builds.yml") }
    let(:dependency_builds)             { {dependency.to_sym => [] } }
    let(:sha256)                        { "sha256-mocked" }
    let(:sha256_1)                      { "sha256-mocked-1" }
    let(:gpg_signature_mocked_1)        { "gpg_signature_mocked_1" }
    let(:gpg_signature_mocked_2)        { "gpg_signature_mocked_2" }

    before do
      WebMock.disable!
      File.open(builds_file, "w") do |file|
        file.write dependency_builds.to_yaml
      end
    end

    after do
      WebMock.enable!
    end

    shared_examples_for "non pre-release builds are triggered by <dependency>-new.yaml" do |verification_type|
      let(:commit_message_1) {"Enqueue #{dependency} - #{expected_version_1}"}
      let(:commit_message_2) {"Enqueue #{dependency} - #{expected_version_2}"}

      before do
        if verification_type == 'sha256'
          allow(described_class).to receive(:shasum_256_verification).with(source_url_1).and_return(["sha256", sha256])
          allow(described_class).to receive(:shasum_256_verification).with(source_url_2).and_return(["sha256", sha256_1])
        elsif verification_type == 'gpg'
          allow(described_class).to receive(:build_verifications_for).with(dependency, expected_version_1).and_return([['gpg-rsa-key-id', 'gpg-key-mocked'], ['gpg-signature', gpg_signature_mocked_1]])
          allow(described_class).to receive(:build_verifications_for).with(dependency, expected_version_2).and_return([['gpg-rsa-key-id', 'gpg-key-mocked'], ['gpg-signature', gpg_signature_mocked_2]])
        end

        allow(Dir).to receive(:chdir).and_call_original
        allow(GitClient).to receive(:add_file).and_return(nil)
        allow(GitClient).to receive(:safe_commit).with(commit_message_1).and_return(nil)
        allow(GitClient).to receive(:safe_commit).with(commit_message_2).and_return(nil)

        File.open(dependency_new_versions_file, "w") do |file|
          file.write new_versions.to_yaml
        end

        subject.enqueue_build
      end

      context 'there are multiple versions submitted to be built' do
        it 'switches to the binary-builds directory to commit, then back' do
          expect(Dir).to have_received(:chdir).with(binary_builds_dir).twice
        end

        it 'git adds <dep>-builds.yml once for each version' do
          expect(GitClient).to have_received(:add_file).with(builds_file).twice
        end

        context 'for each distinct version' do
          let(:committed_dependency) { YAML.load_file(builds_file) }

          it 'has a single version number in a commit message' do
            expect(GitClient).to have_received(:safe_commit).with(commit_message_1)
            expect(GitClient).to have_received(:safe_commit).with(commit_message_2)
          end

          it 'has a single version number in the <dependency>-builds.yml file' do
            expect(committed_dependency[dependency].size).to eq 1
          end

          it 'has the version number in the <dependency>-builds.yml file' do
            expect(committed_dependency[dependency][0]['version']).to eq expected_version_1
          end

          it 'has the correct verification in the <dependency>-builds.yml file' do
            if (verification_type == 'sha256')
              expect(committed_dependency[dependency][0].size).to eq 2
              expect(committed_dependency[dependency][0]['sha256']).to eq sha256
            elsif (verification_type == 'gpg')
              expect(committed_dependency[dependency][0].size).to eq 3
              expect(committed_dependency[dependency][0]['gpg-rsa-key-id']).to eq("gpg-key-mocked")
              expect(committed_dependency[dependency][0]['gpg-signature']).to eq(gpg_signature_mocked_1)
            end
          end
        end
      end
    end

    context "godep" do
      let(:dependency)          { "godep" }
      let(:new_versions)        { %w(v63 v64) }
      let(:expected_version_1)  { "v64" }
      let(:expected_version_2)  { "v63" }
      let(:source_url_1)        { "https://github.com/tools/godep/archive/#{expected_version_1}.tar.gz" }
      let(:source_url_2)        { "https://github.com/tools/godep/archive/#{expected_version_2}.tar.gz" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'sha256'
    end

    context "composer" do
      let(:dependency)          { "composer" }
      let(:new_versions)        { %w(1.1.0-RC 1.1.1-alpha1 1.1.3 1.1.2) }
      let(:expected_version_1)  { "1.1.2" }
      let(:expected_version_2)  { "1.1.3" }
      let(:source_url_1)        { "https://getcomposer.org/download/#{expected_version_1}/composer.phar" }
      let(:source_url_2)        { "https://getcomposer.org/download/#{expected_version_2}/composer.phar" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'sha256'
    end

    context "glide" do
      let(:dependency)          { "glide" }
      let(:new_versions)        { %w(v0.10.3 v0.9.2 v0.10.10-rc1) }
      let(:expected_version_1)  { "v0.9.2" }
      let(:expected_version_2)  { "v0.10.3" }
      let(:source_url_1)        { "https://github.com/Masterminds/glide/archive/#{expected_version_1}.tar.gz" }
      let(:source_url_2)        { "https://github.com/Masterminds/glide/archive/#{expected_version_2}.tar.gz" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'sha256'
    end

    context "nginx" do
      let(:dependency)          { "nginx" }
      let(:new_versions)        { %w(1.11.9 1.10.5) }
      let(:expected_version_1)  { "1.10.5" }
      let(:expected_version_2)  { "1.11.9" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'gpg'
    end

    context "node" do
      let(:dependency)          { "node" }
      let(:new_versions)        { %w(0.12.5 5.7.8 5.7.9-rc.4) }
      let(:expected_version_1)  { "5.7.8" }
      let(:expected_version_2)  { "0.12.5" }
      let(:source_url_1)        { "https://nodejs.org/dist/v#{expected_version_1}/node-v#{expected_version_1}.tar.gz" }
      let(:source_url_2)        { "https://nodejs.org/dist/v#{expected_version_2}/node-v#{expected_version_2}.tar.gz" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'sha256'
    end

    context "bower" do
      let(:dependency)          { "bower" }
      let(:new_versions)        { %w(1.6.7 2.8.9) }
      let(:expected_version_1)  { "2.8.9" }
      let(:expected_version_2)  { "1.6.7" }
      let(:source_url_1)        { "https://registry.npmjs.org/bower/-/bower-#{expected_version_1}.tgz" }
      let(:source_url_2)        { "https://registry.npmjs.org/bower/-/bower-#{expected_version_2}.tgz" }

      it_behaves_like "non pre-release builds are triggered by <dependency>-new.yaml", 'sha256'
    end

    context "dotnet" do
      let(:dependency)          { "dotnet" }
      let(:new_versions)        { %w(v1.0.0-preview2.0.1) }
      let(:expected_version)    { "v1.0.0-preview2.0.1" }
      let(:commit_message)      {"Enqueue #{dependency} - #{expected_version}"}

      context 'there is a pre-release version submitted to be built' do
        before do
          allow(Dir).to receive(:chdir).and_call_original
          allow(GitClient).to receive(:add_file).and_return(nil)
          allow(GitClient).to receive(:safe_commit).with(commit_message).and_return(nil)

          File.open(dependency_new_versions_file, "w") do |file|
            file.write new_versions.to_yaml
          end

          subject.enqueue_build
        end

        it 'switches to the binary-builds directory to commit, then back' do
          expect(Dir).to have_received(:chdir).with(binary_builds_dir)
        end

        it 'git adds <dep>-builds.yml once for each version' do
          expect(GitClient).to have_received(:add_file).with(builds_file)
        end

        context 'for each distinct version' do
          let(:committed_dependency) { YAML.load_file(builds_file) }

          it 'has a single version number in a commit message' do
            expect(GitClient).to have_received(:safe_commit).with(commit_message)
          end

          it 'has a single version number in the <dependency>-builds.yml file' do
            expect(committed_dependency[dependency].size).to eq 1
          end

          it 'has the version number in the <dependency>-builds.yml file' do
            expect(committed_dependency[dependency][0]['version']).to eq expected_version
          end

          it 'has the git-commit-sha verification in the <dependency>-builds.yml file' do
              expect(committed_dependency[dependency][0].size).to eq 2
              expect(committed_dependency[dependency][0]['git-commit-sha']).to eq '635cf40e58ede8a53e8b9555e19a6e1ccd6f9fbe'
          end
        end
      end
    end
  end
end
