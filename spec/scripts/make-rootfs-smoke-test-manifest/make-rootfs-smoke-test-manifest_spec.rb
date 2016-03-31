# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh release task' do
  context 'when modifying release blobs' do
    before(:context) do
      `git init ./spec/scripts/make-rootfs-smoke-test-manifest/deployments-buildpacks`
      execute(
        '-c tasks/make-rootfs-smoke-test-manifest.yml ' \
        '-i buildpacks-ci=. ' \
        '-i diego-release=./spec/scripts/make-rootfs-smoke-test-manifest/diego-release ' \
        '-i cflinuxfs2-rootfs-release=./spec/scripts/make-rootfs-smoke-test-manifest/cflinuxfs2-rootfs-release ' \
        '-i deployments-buildpacks=./spec/scripts/make-rootfs-smoke-test-manifest/deployments-buildpacks ',
        'DEPLOYMENT_NAME' => 'some_deployment')
    end

    after(:context) do
      `rm -rf ./spec/scripts/make-rootfs-smoke-test-manifest/deployments-buildpacks/.git`
    end

    it 'adds the certs to the property_overrides.yml' do
      manifest = run('cat /tmp/build/*/rootfs-smoke-test-manifest-artifacts/deployments/some_deployment/rootfs-smoke-test.yml').to_s
      manifest_yml = YAML.load manifest
      expect(manifest_yml['property_overrides']['cflinuxfs2-rootfs']['trusted_certs']).to include('BEGIN CERTIFICATE')
      expect(manifest_yml['property_overrides']['cflinuxfs2-rootfs']['trusted_certs']).to include('END CERTIFICATE')
    end

    it 'commits the new deployment manifest' do
      commit_msg = run('cd /tmp/build/*/rootfs-smoke-test-manifest-artifacts && git log -1 --format=oneline')
      expect(commit_msg).to include('create smoke test deployment manifest for some_deployment')
    end
  end
end
