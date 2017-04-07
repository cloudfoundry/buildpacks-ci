# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/concourse-binary-builder'
require_relative '../../lib/git-client'
require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'zlib'

describe ConcourseBinaryBuilder do
  context('binary builder is run') do

    let(:platform)                  { 'x86_64' }
    let(:os_name)                   { 'GNU/Linux' }
    let(:git_ssh_key)               { 'mock-git-ssh-key' }
    let(:task_root_dir)             { Dir.mktmpdir }
    let(:binary_builder_dir)        { File.join(task_root_dir, 'binary-builder') }
    let(:builds_yaml_artifacts_dir) { File.join(task_root_dir, 'builds-yaml-artifacts') }
    let(:binary_artifacts_dir)      { File.join(task_root_dir, 'binary-builder-artifacts')}

    let(:built_dir)                 { File.join(task_root_dir, 'built-yaml') }
    let(:built_yaml_contents)       { {dependency => []}.to_yaml }

    let(:builds_dir)                { File.join(task_root_dir, 'builds-yaml') }
    let(:builds_yaml_contents) do
      yaml_hash = {}
      yaml_hash[dependency] = [{'version' => version, verification_type => verification_value}]
      yaml_hash.to_yaml
    end
    let(:output_file_contents)       { (0...8).map { (65 + rand(26)).chr }.join }
    let(:output_file_md5)            { Digest::MD5.hexdigest(output_file_contents) }
    let(:output_file_sha256)         { Digest::SHA256.hexdigest(output_file_contents) }
    let(:output_file_sha256_short)   { output_file_sha256[0..7] }

    let(:flags) { "--name=#{dependency} --version=\"#{version}\" --#{verification_type}=\"#{verification_value}\"" }

    subject { described_class.new(dependency, task_root_dir, git_ssh_key, platform, os_name) }

    before(:each) do
      FileUtils.mkdir_p([File.join(built_dir, 'binary-built-output'), File.join(builds_dir, 'binary-builds'), binary_builder_dir, binary_artifacts_dir])
      FileUtils.rm_rf('/tmp/src')
      FileUtils.rm_rf('/tmp/x86_64-linux-gnu')

      Dir.chdir(File.join(built_dir, 'binary-built-output')) do
        File.open("#{dependency}-built.yml", "w") do |file|
          file.write built_yaml_contents
        end
      end

      Dir.chdir(File.join(builds_dir, 'binary-builds')) do
        File.open("#{dependency}-builds.yml", "w") do |file|
          file.write builds_yaml_contents
        end
      end

      allow(subject).to receive(:system).and_call_original
      allow(subject).to receive(:add_ssh_key_and_update).with(built_dir)

      allow(subject).to receive(:run_binary_builder).with(flags) do |flags|
        Dir.chdir(binary_builder_dir) do
          File.write(output_file, output_file_contents)
        end

        "Source URL: #{source_url}"
      end

      allow(GitClient).to receive(:add_file)
      allow(GitClient).to receive(:safe_commit)
      allow(GitClient).to receive(:set_global_config)
    end

    after(:each) do
      FileUtils.rm_rf(task_root_dir)
    end

    shared_examples_for 'a commit is made in builds-yaml-artifacts with the proper git message' do |automation|
      let(:commit_msg) do
        git_msg = "Build #{dependency} - #{version}\n\n"

        git_yaml = {
          "filename" => output_file_with_sha256,
          'version' => version,
          'md5' => output_file_md5,
          'sha256' => output_file_sha256,
          'source url' => source_url,
          "source #{verification_type}" => verification_value
        }

        git_msg += git_yaml.to_yaml

        git_msg += "\n\n[ci skip]" if automation == 'not automated'
        git_msg
      end

      it 'adds the correct file' do
        if automation == 'automated'
          file_to_commit = File.join(built_dir, 'binary-built-output' ,"#{dependency}-built.yml")
        elsif automation == 'not automated'
          file_to_commit = File.join(builds_dir,'binary-builds', "#{dependency}-builds.yml")
        end

        expect(GitClient).to have_received(:add_file).with(file_to_commit)
      end

      it 'makes the commit with the correct message' do
        expect(GitClient).to have_received(:safe_commit).with(commit_msg)
      end


      it 'makes the commit as buildpacks ci robot' do
        expect(GitClient).to have_received(:set_global_config).with('user.email','cf-ci-bot@suse.de')
        expect(GitClient).to have_received(:set_global_config).with('user.name','SUSE CF CI Server')
      end

      if automation == 'automated'
        it 'makes the commit with a timestamp' do
          Dir.chdir(builds_yaml_artifacts_dir) do
            built_yaml = YAML.load_file(File.join('binary-built-output',"#{dependency}-built.yml"))
            expect(built_yaml[dependency][0]['timestamp']).to_not eq nil
          end
        end
      end
    end


    shared_examples_for 'the resulting tar files are copied to the proper location' do
      it 'copies the built binaries' do
        expect(File.exist? "#{binary_artifacts_dir}/#{output_file_with_sha256}").to eq true
      end
    end

    context 'the dependency is go' do
      let(:dependency)              { 'go' }
      let(:output_file)             { 'go1.6.3.linux-amd64.tar.gz' }
      let(:output_file_with_sha256) { "go1.6.3.linux-amd64-#{output_file_sha256_short}.tar.gz" }
      let(:verification_type)       { 'sha256' }
      let(:verification_value)      { '6326aeed5f86cf18f16d6dc831405614f855e2d416a91fd3fdc334f772345b00' }
      let(:source_url)              { 'https://storage.googleapis.com/golang/go1.6.3.src.tar.gz' }
      let(:version)                 { '1.6.3' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is python' do
      let(:dependency)               { 'python' }
      let(:output_file)              { 'python-2.7.12-linux-x64.tgz' }
      let(:output_file_with_sha256)  { "python-2.7.12-linux-x64-#{output_file_sha256_short}.tgz" }
      let(:verification_type)        { 'sha256' }
      let(:verification_value)       { 'f036b03f2ffd401742bb053f41c25dbe4491e52fc06e49b0dd0e9c1ae5a7baf7' }
      let(:source_url)               { 'https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz' }
      let(:version)                  { '2.7.12' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is php' do
      let(:dependency)               { 'php' }
      let(:output_file)              { 'php-5.6.30-linux-x64.tgz' }
      let(:output_file_with_sha256)  { "php-5.6.30-linux-x64-#{output_file_sha256_short}.tgz" }
      let(:verification_type)        { 'sha256' }
      let(:verification_value)       { 'aaaaaabbbbbccccc' }
      let(:source_url)               { "https://php.net/distributions/php-5.6.30.tar.gz" }
      let(:version)                  { '5.6.30' }
      let(:flags) { "--name=#{dependency} --version=\"#{version}\" --#{verification_type}=\"#{verification_value}\" --php-extensions-file=#{File.join(builds_dir, 'binary-builds', 'php-extensions.yml')}" }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is php7' do
      let(:dependency)               { 'php7' }
      let(:output_file)              { 'php7-7.1.10-linux-x64.tgz' }
      let(:output_file_with_sha256)  { "php7-7.1.10-linux-x64-#{output_file_sha256_short}.tgz" }
      let(:verification_type)        { 'sha256' }
      let(:verification_value)       { 'cccccccaaaaaabbbbb' }
      let(:source_url)               { "https://php.net/distributions/php-7.1.10.tar.gz" }
      let(:version)                  { '7.1.10' }
      let(:flags) { "--name=#{dependency} --version=\"#{version}\" --#{verification_type}=\"#{verification_value}\" --php-extensions-file=#{File.join(builds_dir, 'binary-builds', 'php7-extensions.yml')}" }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'not automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is glide' do
      let(:dependency)               { 'glide' }
      let(:output_file)              { 'glide-v0.11.1-linux-x64.tgz' }
      let(:output_file_with_sha256)  { "glide-v0.11.1-linux-x64-#{output_file_sha256_short}.tgz" }
      let(:verification_type)        { 'sha256' }
      let(:verification_value)       { '3c4958d1ab9446e3d7b2dc280cd43b84c588d50eb692487bcda950d02b9acc4c' }
      let(:source_url)               { 'https://github.com/Masterminds/glide/archive/v0.11.1.tar.gz' }
      let(:version)                  { 'v0.11.1' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is hwc' do
      let(:dependency)               { 'hwc' }
      let(:output_file)              { 'hwc-15.11.1-windows-amd64.zip' }
      let(:output_file_with_sha256)  { "hwc-15.11.1-windows-amd64-#{output_file_sha256_short}.zip" }
      let(:verification_type)        { 'sha256' }
      let(:verification_value)       { 'thisisasha256' }
      let(:source_url)               { 'https://github.com/cloudfoundry-incubator/hwc/archive/15.11.1.tar.gz' }
      let(:version)                  { '15.11.1' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is node' do
      let(:dependency)              { 'node' }
      let(:output_file)             { 'node-4.4.7-linux-x64.tgz' }
      let(:output_file_with_sha256) { "node-4.4.7-linux-x64-#{output_file_sha256_short}.tgz" }
      let(:verification_type)       { 'sha256' }
      let(:verification_value)      { 'cbe1c6e421969dd5639d0fbaa6d3c1f56c0463b87efe75be8594638da4d8fc4f' }
      let(:source_url)              { 'https://nodejs.org/dist/v4.4.7/node-v4.4.7.tar.gz' }
      let(:version)                 { '4.4.7' }

      before { subject.run }

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'

      context 'dependency has already been built' do
        context 'with the same version and the same output file sha256' do
          let(:built_yaml_contents) do
            {'node' => [
              {'version'   => '4.4.7',
               'sha256'    => output_file_sha256,
               'timestamp' => '2016-07-18 15:31:35 UTC'}
            ]}.to_yaml
          end

          it 'has not changed the <dep>-built.yml file' do
            file_yaml_contents = YAML.load_file(File.join(built_dir, 'binary-built-output', "#{dependency}-built.yml")).to_yaml
            expect(built_yaml_contents).to eq(file_yaml_contents)
          end

          it 'syncs the -built file in builds-yaml-artifacts' do
            built_file = File.join(builds_yaml_artifacts_dir, 'binary-built-output', "#{dependency}-built.yml")
            expect(File.exist?(built_file)).to be_truthy
          end

          it_behaves_like 'the resulting tar files are copied to the proper location'
        end

        context 'with the same version but different output file sha256' do
          let(:built_yaml_contents) do
            {'node' => [
              {'version'   => '4.4.7',
               'sha256'    => 'aaabbbcccdddeeefff',
               'timestamp' => '2016-07-18 15:31:35 UTC'}
            ]}.to_yaml
          end

          it 'adds the new build to the <dep>-built.yml file' do
            file_yaml_contents = YAML.load_file(File.join(built_dir, 'binary-built-output', "#{dependency}-built.yml"))
            expect(file_yaml_contents['node'].count).to eq(2)
          end

          it 'syncs the -built file in builds-yaml-artifacts' do
            built_file = File.join(builds_yaml_artifacts_dir, 'binary-built-output', "#{dependency}-built.yml")
            expect(File.exist?(built_file)).to be_truthy
          end

          it_behaves_like 'the resulting tar files are copied to the proper location'
        end
      end
    end

    context 'the dependency is dotnet' do
      let(:dependency)              { 'dotnet' }
      let(:output_file)             { 'dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz' }
      let(:output_file_with_sha256) { "dotnet.1.0.0-preview2-003131.linux-amd64-#{output_file_sha256_short}.tar.xz" }
      let(:verification_type)       { 'git-commit-sha' }
      let(:verification_value)      { 'this-is-a-commit-sha' }
      let(:source_url)              { 'https://github.com/dotnet/cli' }
      let(:version)                 { 'v1.0.0-preview2.0.1' }

      before do
        expect(subject).to receive(:system).with('gunzip', /\.tar\.gz$/) do |_, name|
          File.rename name, name.gsub(/\.gz/, '')
        end
        expect(subject).to receive(:system).with('xz', /\.tar$/) do |_, name|
          File.rename name, "#{name}.xz"
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is bower' do
      let(:dependency)              { 'bower' }
      let(:output_file)             { 'bower-1.77.90.tgz' }
      let(:output_file_with_sha256) { "bower-1.77.90-#{output_file_sha256_short}.tgz" }
      let(:verification_type)       { 'sha256' }
      let(:verification_value)      { output_file_sha256 }
      let(:source_url)              { 'https://registry.npmjs.org/bower/-/bower-1.77.90.tgz' }
      let(:version)                 { '1.77.90' }

      before do
        expect(subject).to receive(:system).with("curl -L #{source_url} -o #{binary_builder_dir}/bower-1.77.90.tgz") do
          Dir.chdir(binary_builder_dir) do
            File.write(output_file, output_file_contents)
          end
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is yarn' do
      let(:dependency)              { 'yarn' }
      let(:output_file)             { 'yarn-v0.19.1.tar.gz' }
      let(:output_file_with_sha256) { "yarn-v0.19.1-#{output_file_sha256_short}.tar.gz" }
      let(:verification_type)       { 'sha256' }
      let(:verification_value)      { output_file_sha256 }
      let(:source_url)              { 'https://yarnpkg.com/downloads/0.19.1/yarn-v0.19.1.tar.gz' }
      let(:version)                 { '0.19.1' }

      before do
        expect(subject).to receive(:system).with("curl -L #{source_url} -o #{binary_builder_dir}/yarn-v0.19.1.tar.gz") do
          Dir.chdir(binary_builder_dir) do
            File.write(output_file, output_file_contents)
          end
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'
    end

    context 'the dependency is composer' do
      let(:dependency)              { 'composer' }
      let(:output_file)             { 'composer-1.2.0.phar' }
      let(:output_file_with_sha256) { "composer-1.2.0-#{output_file_sha256_short}.phar" }
      let(:verification_type)       { 'sha256' }
      let(:verification_value)      { output_file_sha256 }
      let(:source_url)              { 'https://getcomposer.org/download/1.2.0/composer.phar' }
      let(:version)                 { '1.2.0' }

      before do
        expect(subject).to receive(:system).with("curl -L #{source_url} -o #{binary_builder_dir}/composer-1.2.0.phar") do
          Dir.chdir(binary_builder_dir) do
            File.write(output_file, output_file_contents)
          end
        end

        subject.run
      end

      it_behaves_like 'a commit is made in builds-yaml-artifacts with the proper git message', 'automated'
      it_behaves_like 'the resulting tar files are copied to the proper location'

    end
  end
end
