# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir) { Dir.mktmpdir }
  let(:binary_builds_dir) { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }
  let(:manifest_file) { File.join(buildpack_dir, 'manifest.yml') }
  let(:dep_url) { "https://#{dependencies_host_domain}/path-to-built-binary" }
  let(:dependency) { 'bower' }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_builds_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do

    before do
      allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
        Build bower - #{expected_version}
        filename: binary-builder/bower-#{expected_version}.tgz, md5: doesnotmatteratall, sha256: alsoignoredforthistest
      COMMIT
    end

    context 'the buildpack is dotnet-core, the dependency is bower' do
      let(:buildpack) { 'dotnet-core' }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: dotnet-core

          default_versions:
            - name: bower
              version: 1.77.88

          url_to_dependency_map:
            - match: bower-(\d+\.\d+\.\d+)\.tgz
              name: bower
              version: $1

          dependencies:
            - name: bower
              version: 1.77.88
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/bower/bower-1.7.9.tgz
              md5: doesnotmatteratall
        MANIFEST
        File.open(manifest_file, 'w') do |file|
          file.write buildpack_manifest_contents
        end
      end

      context 'the new version of bower is 99.00.11' do
        let (:expected_version) { '99.00.11' }
        def manifest # no let, we don't want to memoise
          YAML.load_file(manifest_file)
        end

        before do
          subject.run!
        end

        it 'adds the latest version to dependencies' do
          dependency_in_manifest = manifest['dependencies'].find { |dep| dep['name'] == dependency && dep['version'] == expected_version }
          expect(dependency_in_manifest['version']).to eq('99.00.11')
        end

        it 'drops the previous version from dependencies' do
          not_found_in_manifest = manifest['dependencies'].find { |dep| dep['name'] == dependency && dep['version'] == '1.77.88' }
          expect(not_found_in_manifest).to be_nil
        end

        it 'adds the latest version to default_versions' do
          default_version_in_manifest = manifest['default_versions'].find { |dep| dep['name'] == dependency && dep['version'] == expected_version }
          expect(default_version_in_manifest['version']).to eq('99.00.11')
        end

        it 'drops the previous version from default_versions' do
          not_found_in_manifest = manifest['default_versions'].find { |dep| dep['name'] == dependency && dep['version'] == '1.77.88' }
          expect(not_found_in_manifest).to be_nil
        end
      end
    end
  end
end
