# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/concourse-binary-builder'
require 'yaml'
require 'tmpdir'
require 'fileutils'

describe ConcourseBinaryBuilder do
  let(:dependency)        { 'go' }
  let(:git_ssh_key)       { 'mock-git-ssh-key' }
  let(:task_root_dir)     { Dir.mktmpdir }
  let(:binary_builder_dir){ File.join(task_root_dir, 'binary-builder') }
  let(:builds_yaml_artifacts_dir) {File.join(task_root_dir, 'builds-yaml-artifacts')}
  let(:built_dir)         { File.join(task_root_dir, 'built-yaml') }
  let(:builds_dir)        { File.join(task_root_dir, 'builds-yaml') }
  let(:source_sha256)     { '6326aeed5f86cf18f16d6dc831405614f855e2d416a91fd3fdc334f772345b00'}
  let(:source_url)        {'https://storage.googleapis.com/golang/go1.6.3.src.tar.gz'}
  let(:version)           { '1.6.3' }
  let(:flags)             { "--name=#{dependency} --version=\"#{version}\" --sha256=\"#{source_sha256}\"" }



  subject { described_class.new(dependency, task_root_dir, binary_builder_dir , git_ssh_key) }

  before do
    built_yaml_contents= <<-HEREDOC
---
go: []
HEREDOC

    builds_yaml_contents= <<-HEREDOC
---
go:
- version: 1.6.3
  sha256: 6326aeed5f86cf18f16d6dc831405614f855e2d416a91fd3fdc334f772345b00
HEREDOC

    Dir.chdir(task_root_dir) do
      FileUtils.mkdir_p(['built-yaml', 'builds-yaml','binary-builder'])
      File.open("./built-yaml/#{dependency}-built.yml", "w") do |file|
        file.write built_yaml_contents
      end

      File.open("./builds-yaml/#{dependency}-builds.yml", "w") do |file|
        file.write builds_yaml_contents
      end
    end

    Dir.chdir(builds_dir) do
      `git init`
    end

    allow(subject).to receive(:add_ssh_key_and_update).with(built_dir, 'binary-built-output')

    expect(subject).to receive(:run_binary_builder).with(flags) do |flags|
      Dir.chdir(binary_builder_dir) do
        `touch build.tgz`
        `touch go1.6.3.linux-amd64.tar.gz`
      end

      "- url: #{source_url}"
    end
  end

  after do
    FileUtils.rm_rf(task_root_dir)
  end



  context 'binary builder is run' do
    let(:output_file) { 'go1.6.3.linux-amd64.tar.gz' }

    before { subject.run }

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

      md5sum = Digest::MD5.file(File.join(binary_builder_dir,output_file)).hexdigest
      shasum = Digest::SHA256.file(File.join(binary_builder_dir,output_file)).hexdigest

      expect(commit_msg).to include(output_file)
      expect(commit_msg).to include("md5: #{md5sum}")
      expect(commit_msg).to include("sha256: #{shasum}")
    end
  end
end
