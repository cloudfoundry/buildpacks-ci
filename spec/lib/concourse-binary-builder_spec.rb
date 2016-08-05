# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/concourse-binary-builder'
require 'yaml'
require 'tmpdir'
require 'fileutils'

describe ConcourseBinaryBuilder do
  context('binary builder is run') do

    let(:git_ssh_key) { 'mock-git-ssh-key' }
    let(:task_root_dir) { Dir.mktmpdir }
    let(:binary_builder_dir) { File.join(task_root_dir, 'binary-builder') }
    let(:builds_yaml_artifacts_dir) { File.join(task_root_dir, 'builds-yaml-artifacts') }
    let(:binary_artifacts_dir) {File.join(task_root_dir, 'binary-builder-artifacts')}
    let(:final_artifact_dir) {File.join(binary_artifacts_dir, 'final-artifact')}

    let(:built_dir) { File.join(task_root_dir, 'built-yaml') }
    let(:built_yaml_contents) { {dependency => []}.to_yaml }

    let(:builds_dir) { File.join(task_root_dir, 'builds-yaml') }
    let(:builds_yaml_contents) do
      yaml_hash = {}
      yaml_hash[dependency] = [{'version' => version, 'sha256' => source_sha256}]
      yaml_hash.to_yaml
    end

    let(:flags) { "--name=#{dependency} --version=\"#{version}\" --sha256=\"#{source_sha256}\"" }


    subject { described_class.new(dependency, task_root_dir, git_ssh_key) }

    before(:each) do
      FileUtils.mkdir_p([built_dir, builds_dir, binary_builder_dir])
      FileUtils.rm_rf('/tmp/src')
      FileUtils.rm_rf('/tmp/x86_64-linux-gnu')

      Dir.chdir(built_dir) do
        File.open("#{dependency}-built.yml", "w") do |file|
          file.write built_yaml_contents
        end
        `git init`
      end

      Dir.chdir(builds_dir) do
        File.open("#{dependency}-builds.yml", "w") do |file|
          file.write builds_yaml_contents
        end
        `git init`
      end

      allow(subject).to receive(:add_ssh_key_and_update).with(built_dir, 'binary-built-output')

      allow(subject).to receive(:run_binary_builder).with(flags) do |flags|
        Dir.chdir(binary_builder_dir) do
          `touch #{output_file}`
        end

        if dependency == "glide" or dependency == "godep" then
            FileUtils.mkdir_p('/tmp/src')
            `touch /tmp/src/main.go`
        else
            FileUtils.mkdir_p('/tmp/x86_64-linux-gnu')
            `touch /tmp/x86_64-linux-gnu/main.c`
        end


        "- url: #{source_url}"
      end
    end

    after(:each) do
      FileUtils.rm_rf(task_root_dir)
    end

    shared_examples_for 'a commit is made in builds-yaml-artifacts with the proper git message' do |automation|

      it 'makes the commit with dependency + version' do
        commit_msg = `cd #{builds_yaml_artifacts_dir} && git log -1 HEAD`
        expect(commit_msg).to include("Build #{dependency} - #{version}")
      end

      it 'makes the commit with source url and sha256' do
        commit_msg = `cd #{builds_yaml_artifacts_dir} && git log -1 HEAD`

        expect(commit_msg).to include("source sha256: #{source_sha256}")
        expect(commit_msg).to include("source url: #{source_url}")
      end

      it 'makes the commit with output filename, md5, and sha256' do
        commit_msg = `cd #{builds_yaml_artifacts_dir} && git log -1 HEAD`

        md5sum = Digest::MD5.file(File.join(binary_builder_dir, output_file)).hexdigest
        shasum = Digest::SHA256.file(File.join(binary_builder_dir, output_file)).hexdigest

        expect(commit_msg).to include(output_file)
        expect(commit_msg).to include("md5: #{md5sum}")
        expect(commit_msg).to include("sha256: #{shasum}")
      end

      it 'has ci skip if necessary ' do
        commit_msg = `cd #{builds_yaml_artifacts_dir} && git log -1 HEAD`

        if automation == 'automated'
          expect(commit_msg).not_to include("[ci skip]")
        elsif automation == 'not automated'
          expect(commit_msg).to include("[ci skip]")
        end
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

      it 'copies the source to build.tgz' do
        expect(File.exist? "#{final_artifact_dir}/build.tgz").to eq true
      end
    end

    context 'the dependency is go' do
      let(:dependency) { 'go' }
      let(:output_file) { 'go1.6.3.linux-amd64.tar.gz' }
      let(:source_sha256) { '6326aeed5f86cf18f16d6dc831405614f855e2d416a91fd3fdc334f772345b00' }
      let(:source_url) { 'https://storage.googleapis.com/golang/go1.6.3.src.tar.gz' }
      let(:version) { '1.6.3' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is python' do
      let(:dependency) { 'python' }
      let(:output_file) { 'python-2.7.12-linux-x64.tgz' }
      let(:source_sha256) { 'f036b03f2ffd401742bb053f41c25dbe4491e52fc06e49b0dd0e9c1ae5a7baf7' }
      let(:source_url) { 'https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz' }
      let(:version) { '2.7.12' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is glide' do
      let(:dependency) { 'glide' }
      let(:output_file) { 'glide-v0.11.1-linux-x64.tgz' }
      let(:source_sha256) { '3c4958d1ab9446e3d7b2dc280cd43b84c588d50eb692487bcda950d02b9acc4c' }
      let(:source_url) { 'https://github.com/Masterminds/glide/archive/v0.11.1.tar.gz' }
      let(:version) { 'v0.11.1' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end


    context 'the dependency is node' do
      let(:dependency) { 'node' }
      let(:output_file) { 'node-4.4.7-linux-x64.tgz' }
      let(:source_sha256) { 'cbe1c6e421969dd5639d0fbaa6d3c1f56c0463b87efe75be8594638da4d8fc4f' }
      let(:source_url) { 'https://nodejs.org/dist/v4.4.7/node-v4.4.7.tar.gz' }
      let(:version) { '4.4.7' }


      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is composer' do
      let(:dependency)    { 'composer' }
      let(:output_file)   { 'composer-1.2.0.phar' }
      let(:source_sha256) { 'dc80131545ed7f7b1369ae058824587f0718892f6a84bd86cfb0f28ab5e39095' }
      let(:source_url)    { 'https://getcomposer.org/download/1.2.0/composer.phar' }
      let(:version)       { '1.2.0' }


      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end
  end
end
