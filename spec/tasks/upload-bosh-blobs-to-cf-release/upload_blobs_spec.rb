# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task', :fly do
  context 'when modifying release blobs' do
    def do_release(artifacts, language)
      execute("-c tasks/upload-bosh-blobs-to-cf-release/task.yml " \
              '-i buildpacks-ci=. ' \
              '-i cf-release=./spec/tasks/upload-bosh-blobs-to-cf-release/cf-release ' \
              '-i buildpack-bosh-release=. ' \
              "-i buildpack-github-release=./spec/tasks/upload-bosh-blobs-to-cf-release/#{language}-buildpack-github-release " \
              "-o cf-release-artifacts=#{artifacts}",
              'BUILDPACK' => "#{language}")
    end

    context 'for java buildpack' do
      before(:context) do
        @artifacts = Dir.mktmpdir
        do_release(@artifacts, 'java')
      end

      after(:context) do
        FileUtils.rm_rf @artifacts
      end

      it 'removes the corresponding key from the blobs.yml' do
        parsed_blobs = YAML.load_file("#{@artifacts}/config/blobs.yml")
        expect(parsed_blobs.keys).to match_array([
          "go-buildpack/go_buildpack-cached-v1.1.zip",
          "java-buildpack/java-buildpack-offline-v1.1.zip",
          "java-buildpack/java-buildpack-v1.2.zip"
        ])
      end

      it 'adds the new blob to the right directory' do
        dirs = Dir.entries("#{@artifacts}/blobs")
        expect(dirs).to include('java-buildpack')
      end
    end

    context 'for go buildpack' do
      before(:context) do
        @artifacts = Dir.mktmpdir
        do_release(@artifacts, 'go')
      end

      after(:context) do
        FileUtils.rm_rf @artifacts
      end

      it 'removes the corresponding key from the blobs.yml' do
        parsed_blobs = YAML.load_file("#{@artifacts}/config/blobs.yml")
        expect(parsed_blobs.keys).to match_array([
          "go-buildpack/go_buildpack-cached-v1.2.zip",
          "java-buildpack/java-buildpack-offline-v1.1.zip",
          "java-buildpack/java-buildpack-v1.1.zip"
        ])
      end

      it 'adds the new blob to the right directory' do
        dirs = Dir.entries("#{@artifacts}/blobs")
        expect(dirs).to include('go-buildpack')
      end
    end
  end
end
