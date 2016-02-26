# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task' do
  context 'when modifying release blobs' do
    before(:context) do
      execute('-c tasks/create-release.yml ' \
              '-i buildpacks-ci=. ' \
              '-i cf-release=./spec/scripts/release/cf/cf-release ' \
              '-i java-buildpack-github-release=./spec/scripts/release/cf/java-buildpack-github-release ' \
              '-i java-offline-buildpack-github-release=./spec/scripts/release/cf/java-offline-buildpack-github-release ' \
              '-i go-buildpack-github-release=./spec/scripts/release/cf/go-buildpack-github-release ' \
              '-i python-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ' \
              '-i nodejs-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ' \
              '-i ruby-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ' \
              '-i php-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ' \
              '-i staticfile-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ' \
              '-i binary-buildpack-github-release=./spec/scripts/release/cf/empty-buildpack-github-release ')
    end

    it 'overwrites the correct buildpack .zip file' do
      java_buildpack = run('cat /tmp/build/*/cf-release/blobs/java-buildpack/java-buildpack-v*.zip').to_s
      java_offline_buildpack = run('cat /tmp/build/*/cf-release/blobs/java-buildpack/java-buildpack-offline*.zip').to_s
      go_buildpack = run('cat /tmp/build/*/cf-release/blobs/go-buildpack/*.zip').to_s
      expect(java_buildpack).to eq('java')
      expect(java_offline_buildpack).to eq('java-offline')
      expect(go_buildpack).to eq('go')
    end
  end
end
