# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_built_out_dir)     { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create('dotnet-runtime', 'dotnet-core', buildpack_dir, "", binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dependency)   { 'dotnet-runtime' }
    let(:buildpack)    { 'dotnet-core' }
    let(:buildpack_manifest_contents) do
     <<~MANIFEST
        ---
        language: dotnet-core
        dependencies:
          - name: dotnet-runtime
            version: 1.0.0
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet-runtime/dotnet-runtime.1.0.0.linux-amd64.tar.gz
            sha256: oldSHA256_1_0_0
            cf_stacks:
            - cflinuxfs2
          - name: dotnet-runtime
            version: 1.0.1
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet-runtime/dotnet-runtime.1.0.1.linux-amd64.tar.gz
            sha256: oldSHA256_1_0_1
            cf_stacks:
            - cflinuxfs2
          - name: dotnet-runtime
            version: 1.0.3
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet-runtime/dotnet-runtime.1.0.3.linux-amd64.tar.gz
            sha256: oldSHA256_1_0_3
            cf_stacks:
            - cflinuxfs2
          - name: dotnet-runtime
            version: 1.1.0
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet-runtime/dotnet-runtime.1.1.0.linux-amd64.tar.gz
            sha256: oldSHA256_1_1_0
            cf_stacks:
            - cflinuxfs2
        MANIFEST
    end


    before do
      File.open(manifest_file, "w") do |file|
        file.write buildpack_manifest_contents
      end

      allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/dotnet-runtime-built.yml').and_return <<~COMMIT
        Build dotnet-runtime - #{new_version}

        ---
        filename: dotnet-runtime.#{new_version}.linux-amd64.tar.gz
        version: #{new_version}
        md5: aaaabbbb22224444
        sha256: newSHA256
      COMMIT
    end

    context 'the built runtime is not in the manifest' do
      let(:new_version)           { '1.1.1' }

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '1.1.1'}
        expect(dependency_in_manifest["version"]).to eq("1.1.1")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet-runtime/dotnet-runtime.1.1.1.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency}.count).to eq 5
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end

    context 'the built runtime is present in the manifest' do
      let(:new_version)           { '1.1.0' }

      it 'does not add a version to the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency}.count).to eq 4
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end
  end
end
