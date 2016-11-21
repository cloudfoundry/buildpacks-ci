# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task' do
  context 'when modifying release blobs' do
    before(:context) do
      `git init ./spec/tasks/make-rootfs-smoke-test-manifest/deployments-buildpacks`
      execute(
        '-c tasks/make-rootfs-smoke-test-manifest/task.yml ' \
        '-i buildpacks-ci=. ' \
        '-i cflinuxfs2-rootfs-release=./spec/tasks/make-rootfs-smoke-test-manifest/cflinuxfs2-rootfs-release ' \
        '-i deployments-buildpacks=./spec/tasks/make-rootfs-smoke-test-manifest/deployments-buildpacks ',
        'DEPLOYMENT_NAME' => 'some_deployment')
    end

    after(:context) do
      `rm -rf ./spec/tasks/make-rootfs-smoke-test-manifest/deployments-buildpacks/.git`
    end

    it 'adds the certs to the property_overrides.yml' do
      manifest = run('cat /tmp/build/*/rootfs-smoke-test-manifest-artifacts/deployments/some_deployment/rootfs-smoke-test.yml').strip
      expect(manifest).to eq('manifest')
    end

    it 'commits the new deployment manifest' do
      commit_msg = run('cd /tmp/build/*/rootfs-smoke-test-manifest-artifacts && git log -1 --format=oneline')
      expect(commit_msg).to include('create rootfs with smoke test deployment manifest for some_deployment')
    end
  end
end
