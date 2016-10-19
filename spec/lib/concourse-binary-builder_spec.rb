# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/concourse-binary-builder'
require_relative '../../lib/git-client'
require 'yaml'
require 'tmpdir'
require 'fileutils'

describe ConcourseBinaryBuilder do
  context('binary builder is run') do

    let(:platform) { 'x86_64' }
    let(:os_name)  { 'GNU/Linux' }
    let(:git_ssh_key) { 'mock-git-ssh-key' }
    let(:task_root_dir) { Dir.mktmpdir }
    let(:binary_builder_dir) { File.join(task_root_dir, 'binary-builder') }
    let(:builds_yaml_artifacts_dir) { File.join(task_root_dir, 'builds-yaml-artifacts') }
    let(:binary_artifacts_dir) {File.join(task_root_dir, 'binary-builder-artifacts')}

    let(:built_dir) { File.join(task_root_dir, 'built-yaml') }
    let(:built_yaml_contents) { {dependency => []}.to_yaml }

    let(:builds_dir) { File.join(task_root_dir, 'builds-yaml') }
    let(:builds_yaml_contents) do
      yaml_hash = {}
      yaml_hash[dependency] = [{'version' => version, verification_type => verification_value}]
      yaml_hash.to_yaml
    end

    let(:flags) { "--name=#{dependency} --version=\"#{version}\" --#{verification_type}=\"#{verification_value}\"" }

    subject { described_class.new(dependency, task_root_dir, git_ssh_key, platform, os_name) }

    before(:each) do
      FileUtils.mkdir_p([built_dir, builds_dir, binary_builder_dir, binary_artifacts_dir])
      FileUtils.rm_rf('/tmp/src')
      FileUtils.rm_rf('/tmp/x86_64-linux-gnu')

      Dir.chdir(built_dir) do
        File.open("#{dependency}-built.yml", "w") do |file|
          file.write built_yaml_contents
        end
      end

      Dir.chdir(builds_dir) do
        File.open("#{dependency}-builds.yml", "w") do |file|
          file.write builds_yaml_contents
        end
      end

      allow(subject).to receive(:system).and_call_original
      allow(subject).to receive(:add_ssh_key_and_update).with(built_dir, 'binary-built-output')

      allow(subject).to receive(:run_binary_builder).with(flags) do |flags|
        Dir.chdir(binary_builder_dir) do
          `touch #{output_file}`
        end

        "- url: #{source_url}"
      end

      allow(GitClient).to receive(:add_file)
      allow(GitClient).to receive(:safe_commit)
      allow(GitClient).to receive(:set_global_config)
    end

    after(:each) do
      FileUtils.rm_rf(task_root_dir)
    end

    shared_examples_for 'a commit is made in builds-yaml-artifacts with the proper git message' do |automation|
      let(:md5sum) { md5sum = Digest::MD5.file(File.join(binary_builder_dir, output_file)).hexdigest }
      let(:shasum) { shasum = Digest::SHA256.file(File.join(binary_builder_dir, output_file)).hexdigest }

      let(:commit_msg) do
        git_msg = "Build #{dependency} - #{version}\n\nfilename: binary-builder/#{output_file}, md5: #{md5sum}, sha256: #{shasum}"
        git_msg += "\n\nsource url: #{source_url}, source #{verification_type}: #{verification_value}"
        git_msg += "\n\n[ci skip]" if automation == 'not automated'
        git_msg
      end

      it 'adds the correct file' do
        if automation == 'automated'
          file_to_commit = File.join(built_dir, "#{dependency}-built.yml")
        elsif automation == 'not automated'
          file_to_commit = File.join(builds_dir, "#{dependency}-builds.yml")
        end

        expect(GitClient).to have_received(:add_file).with(file_to_commit)
      end

      it 'makes the commit with the correct message' do
        expect(GitClient).to have_received(:safe_commit).with(commit_msg)
      end


      it 'makes the commit as buildpacks ci robot' do
        expect(GitClient).to have_received(:set_global_config).with('user.email','cf-buildpacks-eng@pivotal.io')
        expect(GitClient).to have_received(:set_global_config).with('user.name','CF Buildpacks Team CI Server')
      end

      if automation == 'automated'
        it 'makes the commit with a timestamp' do
          Dir.chdir(builds_yaml_artifacts_dir) do
            built_yaml = YAML.load_file("#{dependency}-built.yml")
            expect(built_yaml[dependency][0]['timestamp']).to_not eq nil
          end
        end
      end
    end


    shared_examples_for 'the resulting tar files are copied to the proper location' do
      it 'copies the built binaries' do
        expect(File.exist? "#{binary_artifacts_dir}/#{output_file}").to eq true
      end
    end

    context 'the dependency is go' do
      let(:dependency) { 'go' }
      let(:output_file) { 'go1.6.3.linux-amd64.tar.gz' }
      let(:verification_type) { 'sha256' }
      let(:verification_value) { '6326aeed5f86cf18f16d6dc831405614f855e2d416a91fd3fdc334f772345b00' }
      let(:source_url) { 'https://storage.googleapis.com/golang/go1.6.3.src.tar.gz' }
      let(:version) { '1.6.3' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is python' do
      let(:dependency) { 'python' }
      let(:output_file) { 'python-2.7.12-linux-x64.tgz' }
      let(:verification_type) { 'sha256' }
      let(:verification_value) { 'f036b03f2ffd401742bb053f41c25dbe4491e52fc06e49b0dd0e9c1ae5a7baf7' }
      let(:source_url) { 'https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz' }
      let(:version) { '2.7.12' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is glide' do
      let(:dependency) { 'glide' }
      let(:output_file) { 'glide-v0.11.1-linux-x64.tgz' }
      let(:verification_type) { 'sha256' }
      let(:verification_value) { '3c4958d1ab9446e3d7b2dc280cd43b84c588d50eb692487bcda950d02b9acc4c' }
      let(:source_url) { 'https://github.com/Masterminds/glide/archive/v0.11.1.tar.gz' }
      let(:version) { 'v0.11.1' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end


    context 'the dependency is node' do
      let(:dependency) { 'node' }
      let(:output_file) { 'node-4.4.7-linux-x64.tgz' }
      let(:verification_type) { 'sha256' }
      let(:verification_value) { 'cbe1c6e421969dd5639d0fbaa6d3c1f56c0463b87efe75be8594638da4d8fc4f' }
      let(:source_url) { 'https://nodejs.org/dist/v4.4.7/node-v4.4.7.tar.gz' }
      let(:version) { '4.4.7' }


      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is dotnet' do
      let(:dependency) { 'dotnet' }
      let(:output_file) { 'dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz' }
      let(:verification_type) { 'git-commit-sha' }
      let(:verification_value) { 'this-is-a-commit-sha' }
      let(:source_url) { 'https://github.com/dotnet/cli' }
      let(:version) { 'v1.0.0-preview2.0.1' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is bower' do
      let(:dependency)         { 'bower' }
      let(:output_file)        { 'bower-1.77.90.tgz' }
      let(:verification_type)  { 'sha256' }
      let(:verification_value) { 'aaabbbccc111222333' }
      let(:source_url)         { 'https://registry.npmjs.org/bower/-/bower-1.77.90.tgz' }
      let(:version)            { '1.77.90' }

      before do
        expect(subject).to receive(:system).with("curl #{source_url} -o #{binary_builder_dir}/bower-1.77.90.tgz") do
          `touch #{binary_builder_dir}/bower-#{version}.tgz`
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is composer' do
      let(:dependency)    { 'composer' }
      let(:output_file)        { 'composer-1.2.0.phar' }
      let(:verification_type)  { 'sha256' }
      let(:verification_value) { 'dc80131545ed7f7b1369ae058824587f0718892f6a84bd86cfb0f28ab5e39095' }
      let(:source_url)    { 'https://getcomposer.org/download/1.2.0/composer.phar' }
      let(:version)       { '1.2.0' }

      before do
        expect(subject).to receive(:system).with("curl #{source_url} -o #{binary_builder_dir}/composer-1.2.0.phar") do
          `touch #{binary_builder_dir}/composer-#{version}.phar`
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'

      context 'dependency has already been built' do
        let(:built_yaml_contents) do
          {dependency => [
            {'version' => '1.2.0',
           'sha256' => '4ed7a99985f8afee337cc22d5fef61b495ab4238dfff3750ac9019e87fc6aae6',
           'timestamp' => '2016-07-18 15:31:35 UTC'}
          ]}.to_yaml
        end

        it 'has not changed the <dep>-built.yml file' do
          file_yaml_contents = YAML.load_file(File.join(built_dir, "#{dependency}-built.yml")).to_yaml
          expect(built_yaml_contents).to eq(file_yaml_contents)
        end

        it 'syncs the -built file in builds-yaml-artifacts' do
          built_file = File.join(builds_yaml_artifacts_dir, "#{dependency}-built.yml")
          expect(File.exist?(built_file)).to be_truthy
        end

        it_behaves_like 'the resulting tar files are copied to the proper location'
      end
    end
  end
end
