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
        key = parsed_blobs.find { |k, _| k == 'java-buildpack/java-buildpack-v3.6.zip' }
        expect(parsed_blobs.keys.count).to eq(2)
        expect(key).to be_nil
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
        key = parsed_blobs.find { |k, _| k == 'go-buildpack/go_buildpack-cached-v1.7.2.zip' }
        expect(parsed_blobs.keys.count).to eq(2)
        expect(key).to be_nil
      end

      it 'adds the new blob to the right directory' do
        dirs = Dir.entries("#{@artifacts}/blobs")
        expect(dirs).to include('go-buildpack')
      end
    end
  end
end
