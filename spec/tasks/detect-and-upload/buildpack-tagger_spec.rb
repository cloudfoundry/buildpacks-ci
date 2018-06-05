# encoding: utf-8

require 'tmpdir'
require 'fileutils'
require_relative '../../../tasks/detect-and-upload/buildpack-tagger'

describe BuildpackTagger do
  let(:task_dir) { Dir.mktmpdir }
  let(:old_version)    { '3.3.3' }
  let(:old_timestamp)  {'12345'}
  let(:git_tags)       { [double(name: 'v1.1.1'), double(name: 'v2.2.2'), double(name: 'v3.3.3')] }
  let(:git_repo_org)   {'some-sort-of-org'}
  let(:buildpack_name) {'testlang'}
  let(:buildpack_package_command) do
    <<~EOF
       export BUNDLE_GEMFILE=cf.Gemfile
       if [ ! -z "$RUBYGEM_MIRROR" ]; then
         bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
       fi
       bundle install
       bundle exec buildpack-packager --uncached
       bundle exec buildpack-packager --cached
       echo 'stack: "$CF_STACK"' >> manifest.yml
       zip *-cached*.zip manifest.yml
       EOF
  end

  before(:each) do
    @new_version = new_version
    @new_timestamp = new_timestamp

    Dir.chdir(task_dir) do
      FileUtils.mkdir_p('buildpack')
      File.write('buildpack/VERSION', new_version)
      File.write('buildpack/cf.Gemfile', 'gem contents')
      File.write('buildpack/compile-extensions', 'gem contents')

      FileUtils.mkdir_p('pivotal-buildpack')
      File.write("pivotal-buildpack/testlang_buildpack-v#{old_version}+#{old_timestamp}.zip",'specfile')

      FileUtils.mkdir_p('pivotal-buildpack-cached')
      File.write("pivotal-buildpack-cached/testlang_buildpack-cached-v#{old_version}+#{old_timestamp}.zip",'specfile')

      FileUtils.mkdir_p('buildpack-artifacts')

      allow(subject).to receive(:`).with('git tag').and_return(git_tags)
      allow(subject).to receive(:`).with("git tag v#{@new_version}")
      allow(subject).to receive(:`).with('date +%s').and_return(@new_timestamp)
      allow(subject).to receive(:`).with(/md5sum/).and_call_original
      allow(subject).to receive(:`).with(/sha256sum/) do |cmd|
        if RUBY_PLATFORM.match /darwin/
          file = cmd.split(' ').last
          `shasum -a 256 #{file}`
        else
          `#{cmd}`
        end
      end

      allow(subject).to receive(:system).with(buildpack_package_command) do
        File.write("testlang_buildpack-v#{@new_version}.zip",'specfile')
        File.write("testlang_buildpack-cached-v#{@new_version}.zip",'specfile')
      end

      allow(ENV).to receive(:fetch).with('CF_STACK').and_return('some-stack')
    end
    allow(Octokit).to receive(:tags).with("#{git_repo_org}/#{buildpack_name}").and_return(git_tags)
  end

  after(:each) do
    FileUtils.rm_rf(task_dir)
  end

  subject { described_class.new(File.join(task_dir, 'buildpack'), buildpack_name, git_repo_org) }

  context 'the tag already exists' do
    let(:new_version)  { '3.3.3' }
    let(:new_timestamp) { '09876'}

    it 'does not try to add a git tag' do
      expect(subject).not_to receive(:`).with('git tag v3.3.3')

      subject.run!
    end

    it 'copies the existing buildpacks to the artifacts directory' do
      subject.run!

      Dir.chdir(File.join(task_dir, 'buildpack-artifacts')) do
        output_buildpacks = Dir["*.zip"]
        expect(output_buildpacks).to include('testlang_buildpack-v3.3.3+12345.zip')
        expect(output_buildpacks).to include('testlang_buildpack-cached-v3.3.3+12345.zip')
      end
    end
  end

  context 'the tag does not exist' do
    let(:new_version)   { '4.4.4' }
    let(:new_timestamp) { '09876'}

    it 'adds a tag with the new version' do
      expect(subject).to receive(:`).with('git tag v4.4.4')

      subject.run!
    end

    it 'copies the new buildpacks to the artifacts directory' do
      subject.run!

      Dir.chdir(File.join(task_dir, 'buildpack-artifacts')) do
        output_buildpacks = Dir["*.zip"]
        expect(output_buildpacks).to include('testlang_buildpack-v4.4.4+09876.zip')
        expect(output_buildpacks).to include('testlang_buildpack-cached-some-stack-v4.4.4+09876.zip')
      end
    end

    it 'calculates the md5 and sha256 hashes of the new buildpacks' do
      expect(subject).to receive(:`).with('sha256sum testlang_buildpack-v4.4.4+09876.zip')
      expect(subject).to receive(:`).with('sha256sum testlang_buildpack-cached-some-stack-v4.4.4+09876.zip')

      expect(subject).to receive(:`).with('md5sum testlang_buildpack-v4.4.4+09876.zip')
      expect(subject).to receive(:`).with('md5sum testlang_buildpack-cached-some-stack-v4.4.4+09876.zip')
      subject.run!
    end
  end
end
