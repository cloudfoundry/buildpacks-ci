# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh stacks release task' do
  context 'when uploading blobs' do
    before(:context) do
      `git init ./spec/tasks/create-bosh-release/stacks-release`

      execute('-c tasks/create-bosh-release/task.yml ' \
              '-i buildpacks-ci=. ' \
              '-i blob=./spec/tasks/create-bosh-release/stack-s3 ' \
              '-i version=./spec/tasks/create-bosh-release/version ' \
              '-i release=./spec/tasks/create-bosh-release/stacks-release ',
              'BLOB_NAME' => 'rootfs',
              'BLOB_GLOB' => 'blob/cflinuxfs2-*.tar.gz',
              'RELEASE_NAME' => 'stack',
              'RELEASE_DIR' => 'release')
    end

    it 'modifies config/blobs.yml correctly' do
      output = run('cat /tmp/build/*/release/config/blobs.yml').to_s
      version = run('cat /tmp/build/*/version/number').strip
      this_key = 'rootfs/cflinuxfs2-' + version + '.tar.gz'
      blobs_yaml = YAML.load(output)
      shasum = '005ed7ef85a025b1280cd6133ac4fd9f6f97879b'
      expect(blobs_yaml[this_key]['sha']).to be == shasum
      expect(blobs_yaml[this_key]['size']).to be == 140
    end

    context 'with two individual git commits' do
      it 'has one that contains the blobs.yml' do
        output = run('cd /tmp/build/*/release && git show --pretty="format:" --name-only HEAD~1').strip
        expect(output).to include 'config/blobs.yml'
      end

      it 'has one that contains the final release' do
        output = run('cd /tmp/build/*/release && git show --pretty="format:" --name-only HEAD').strip

        expect(output).to include 'releases/stack/stack-1.22.0-rc.2.yml'
        expect(output).to include 'releases/stack/index.yml'
      end
    end
  end

  context 'private.yml creation' do
    before(:context) do
      @access_key_id = 'an_access_key'
      @secret_access_key = 'a_secret_access_key'

      execute('-c tasks/create-bosh-release/task.yml ' \
              '-i buildpacks-ci=. ' \
              '-i blob=./spec/tasks/create-bosh-release/stack-s3 ' \
              '-i version=./spec/tasks/create-bosh-release/version ' \
              '-i release=./spec/tasks/create-bosh-release/stacks-release ',
              'RELEASE_DIR' => 'release',
              'ACCESS_KEY_ID' => @access_key_id,
              'SECRET_ACCESS_KEY' => @secret_access_key)
    end

    it 'has the correct ACCESS_KEY_ID' do
      private_yml = YAML.load(run('cat /tmp/build/*/release/config/private.yml'))

      expect(private_yml['blobstore']['s3']['access_key_id']).to be == ["redacted ACCESS_KEY_ID"]
    end

    it 'has the correct SECRET_ACCESS_KEY' do
      private_yml = YAML.load(run('cat /tmp/build/*/release/config/private.yml'))
      puts private_yml
      expect(private_yml['blobstore']['s3']['secret_access_key']).to be == ["redacted SECRET_ACCESS_KEY"]
    end
  end
end
