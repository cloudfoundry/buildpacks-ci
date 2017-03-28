# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task' do
  context 'when modifying release blobs' do
    before(:context) do
      execute(
        '-c tasks/make-rootfs-smoke-test-manifest/task.yml ' \
        '-i buildpacks-ci=. ' \
        '-i cflinuxfs2-release=./spec/tasks/make-rootfs-smoke-test-manifest/cflinuxfs2-release ',
        'DEPLOYMENT_NAME' => 'some_deployment')
    end

    it 'adds the certs to the property_overrides.yml' do
      manifest = run('cat /tmp/build/*/rootfs-smoke-test-manifest-artifacts/some_deployment/rootfs-smoke-test.yml').strip
      expect(manifest).to eq('manifest')
    end
  end
end
