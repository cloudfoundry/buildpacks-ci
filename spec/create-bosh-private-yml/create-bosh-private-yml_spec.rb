# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh stacks release task' do
  before(:context) do
    @access_key_id = 'an_access_key'
    @secret_access_key = 'a_secret_access_key'

    execute('-c tasks/create-bosh-private-yml.yml ' \
            '-i buildpacks-ci=. ' \
            '-i stacks-release=./spec/create-bosh-stacks-release/stacks-release',
            ACCESS_KEY_ID: @access_key_id, SECRET_ACCESS_KEY: @secret_access_key
           )
  end

  context 'private.yml creation' do
    it 'has the correct ACCESS_KEY_ID' do
      private_yml = YAML.load(run('cat /tmp/build/*/stacks-release/config/private.yml'))

      expect(private_yml['blobstore']['s3']['access_key_id']).to be == @access_key_id
    end

    it 'has the correct SECRET_ACCESS_KEY' do
      private_yml = YAML.load(run('cat /tmp/build/*/stacks-release/config/private.yml'))
      expect(private_yml['blobstore']['s3']['secret_access_key']).to be == @secret_access_key
    end
  end
end
