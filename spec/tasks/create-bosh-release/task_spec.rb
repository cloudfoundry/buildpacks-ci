# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'
require 'open3'

describe 'create bosh stacks release task', :fly do
  before(:context) do
    @tmp_release = Dir.mktmpdir
    @release_artifacts = Dir.mktmpdir
    FileUtils.cp_r "./spec/tasks/create-bosh-release/stacks-release/.", @tmp_release
    Dir.chdir(@tmp_release) do
      `git init .`
      `git add .`
      `git commit -m 'initial'`
    end

    @access_key_id = 'an_access_key'
    @secret_access_key = 'a_secret_access_key'
    execute('-c tasks/create-bosh-release/task.yml ' \
            '-i buildpacks-ci=. ' \
            '-i buildpack-zip=./spec/tasks/create-bosh-release/stack-s3 ' \
            '-i version=./spec/tasks/create-bosh-release/version ' \
            "-i release=#{@tmp_release} " \
            "-o release-artifacts=#{@release_artifacts} ",
            'BLOB_NAME' => 'rootfs',
            'BLOB_GLOB' => 'buildpack-zip/cflinuxfs2-*.tar.gz',
            'RELEASE_NAME' => 'stack',
            'RELEASE_DIR' => 'release',
            'ACCESS_KEY_ID' => @access_key_id,
            'SECRET_ACCESS_KEY' => @secret_access_key)
  end
  after(:context) do
    FileUtils.rm_rf @tmp_release
    FileUtils.rm_rf @release_artifacts
  end

  context 'when uploading blobs' do
    it 'modifies config/blobs.yml correctly' do
      version = File.read('./spec/tasks/create-bosh-release/version/number').strip
      output = File.read("#{@release_artifacts}/config/blobs.yml")
      this_key = 'rootfs/cflinuxfs2-' + version + '.tar.gz'
      blobs_yaml = YAML.load(output)
      shasum = '005ed7ef85a025b1280cd6133ac4fd9f6f97879b'
      expect(blobs_yaml[this_key]['sha']).to be == shasum
      expect(blobs_yaml[this_key]['size']).to be == 140
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

        expect(output).to include 'releases/stack/stack-1.22.0-rc.2.yml'
        expect(output).to include 'releases/stack/index.yml'
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
