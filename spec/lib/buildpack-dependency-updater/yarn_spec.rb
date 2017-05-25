# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir) { Dir.mktmpdir }
  let(:binary_built_out_dir) { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }
  let(:manifest_file) { File.join(buildpack_dir, 'manifest.yml') }
  let(:dep_url) { "https://#{dependencies_host_domain}/path-to-built-binary" }
  let(:dependency) { 'yarn' }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do

    before do
      allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/yarn-built.yml').and_return <<~COMMIT
        Build yarn - #{expected_version}

        ---
        filename: yarn-v#{expected_version}.tar.gz
        version: #{expected_version}
        md5: doesnotmatteratall
        sha256: alsoignoredforthistest
      COMMIT
    end

    context 'the buildpack is nodejs, the dependency is yarn' do
      let(:buildpack) { 'nodejs' }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: nodejs

          default_versions: []

          url_to_dependency_map:
            - match: yarn-v(\d+\.\d+\.\d+)\.tar\.gz
              name: yarn
              version: "$1"

          dependencies:
            - name: yarn
              version: 0.1.2
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/dependencies/yarn/yarn-v0.1.2.tgz
              md5: doesnotmatteratall
        MANIFEST
        File.open(manifest_file, 'w') do |file|
          file.write buildpack_manifest_contents
        end
      end

      context 'the new version of yarn is 99.00.11' do
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
          not_found_in_manifest = manifest['dependencies'].find { |dep| dep['name'] == dependency && dep['version'] == '0.1.2' }
          expect(not_found_in_manifest).to be_nil
        end
      end
    end
  end
end
