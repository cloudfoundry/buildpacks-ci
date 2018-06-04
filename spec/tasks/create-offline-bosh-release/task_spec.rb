# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'
require 'open3'

describe 'create bosh hwc release task', :fly do
  before(:context) do
    @tmp_release = Dir.mktmpdir
    @release_artifacts = Dir.mktmpdir
    FileUtils.cp_r "./spec/tasks/create-offline-bosh-release/hwc-release/.", @tmp_release
    Dir.chdir(@tmp_release) do
      `git init .`
      `git add .`
      `git commit -m 'initial'`
    end

    @access_key_id = 'an_access_key'
    @secret_access_key = 'a_secret_access_key'
    out = execute('-c tasks/create-offline-bosh-release/task.yml ' \
            '--include-ignored ' \
            '-i buildpacks-ci=. ' \
            '-i buildpack-zip=./spec/tasks/create-offline-bosh-release/hwc-s3 ' \
            '-i version=./spec/tasks/create-offline-bosh-release/version ' \
            "-i release=#{@tmp_release} " \
            "-o release-artifacts=#{@release_artifacts} ",
            'LANGUAGES' => 'hwc',
            'RELEASE_NAME' => 'hwc',
            'RELEASE_DIR' => 'release',
            'ACCESS_KEY_ID' => @access_key_id,
            'SECRET_ACCESS_KEY' => @secret_access_key)
    puts out
  end
  after(:context) do
    FileUtils.rm_rf @tmp_release
    FileUtils.rm_rf @release_artifacts
  end

  context 'when uploading blobs' do
    it 'modifies config/blobs.yml correctly' do
      version = File.read('./spec/tasks/create-offline-bosh-release/version/number').strip
      output = File.read("#{@release_artifacts}/config/blobs.yml")
      this_key = 'hwc-buildpack/hwc_buildpack-cached-windows2012R2-v' + version + '.zip'
      blobs_yaml = YAML.load(output)
      shasum = '9d30a47151776c6c52a436698796d52ab79ff69c'
      expect(blobs_yaml[this_key]['sha']).to be == shasum
      expect(blobs_yaml[this_key]['size']).to be == 4271976
    end

    context 'with two individual git commits' do
      it 'has one that contains the blobs.yml' do
        output, status = Open3.capture2('git show --pretty="format:" --name-only HEAD~1', :chdir => @release_artifacts)
        expect(status).to be_success

        expect(output).to include 'config/blobs.yml'
      end

      it 'has one that contains the final release' do
        output, status = Open3.capture2('git show --pretty="format:" --name-only HEAD', :chdir => @release_artifacts)
        expect(status).to be_success

        expect(output).to include 'releases/hwc/hwc-2.3.16.yml'
        expect(output).to include 'releases/hwc/index.yml'
      end
    end
  end

  context 'private.yml creation' do
    it 'has the correct ACCESS_KEY_ID' do
      private_yml = YAML.load_file("#{@release_artifacts}/config/private.yml")

      expect(private_yml['blobstore']['options']['access_key_id']).to eq @access_key_id
    end

    it 'has the correct SECRET_ACCESS_KEY' do
      private_yml = YAML.load_file("#{@release_artifacts}/config/private.yml")
      puts private_yml
      expect(private_yml['blobstore']['options']['secret_access_key']).to eq @secret_access_key
    end
  end
end
