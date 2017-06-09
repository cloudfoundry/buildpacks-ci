# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task' do
  context 'when modifying release blobs' do
    before(:context) do
      @artifacts = Dir.mktmpdir
      execute(
        '-c tasks/make-rootfs-smoke-test-manifest/task.yml ' \
        '-i buildpacks-ci=. ' \
        '-i cflinuxfs2-release=./spec/tasks/make-rootfs-smoke-test-manifest/cflinuxfs2-release ' \
        "-o rootfs-smoke-test-manifest-artifacts=#{@artifacts}",
        'DEPLOYMENT_NAME' => 'some_deployment')
    end
    after(:context) do
      FileUtils.rm_rf @artifacts
    end

    it 'adds the certs to the property_overrides.yml' do
      puts @artifacts
      manifest = File.read("#{@artifacts}/some_deployment/rootfs-smoke-test.yml").strip
      expect(manifest).to eq('manifest')
    end
  end
end
