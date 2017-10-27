# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_built_out_dir)        { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create('dotnet', 'dotnet-core', buildpack_dir, binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dependency)   { 'dotnet' }
    let(:buildpack)    { 'dotnet-core' }
    let(:sdk_tools_file) { File.join(buildpack_dir, 'dotnet-sdk-tools.yml') }
    let(:buildpack_manifest_contents) do
     <<~MANIFEST
        ---
        language: dotnet-core
        default_versions:
          - name: dotnet
            version: 1.0.0-preview3-006666
        dependencies:
          - name: dotnet
            version: 1.0.0-preview2-003121
            cf_stacks:
              - cflinuxfs2
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-003121.linux-amd64.tar.gz
            sha256: oldSHA256_preview2_003121
          - name: dotnet
            version: 1.0.0-preview3-006666
            cf_stacks:
              - cflinuxfs2
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview3-006666.linux-amd64.tar.gz
            sha256: oldSHA256_preview3_006666
          - name: dotnet
            version: 1.0.0-preview1-002702
            cf_stacks:
              - cflinuxfs2
            uri: https://go.microsoft.com/fwlink/?LinkID=798405
            sha256: oldSHA256_preview1_002702
          - name: dotnet
            version: 1.0.0-preview2-003131
            cf_stacks:
              - cflinuxfs2
            uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz
            sha256: oldSHA256_preview2_003131
        MANIFEST
    end

    let(:sdk_tools_contents) do
    <<~SDK_TOOLS
      ---
      project_json:
        - 1.0.0-preview1-002702
        - 1.0.0-preview2-003121
        - 1.0.0-preview2-003131
      msbuild:
        - 1.0.0-preview3-006666
      SDK_TOOLS
    end

    before do
      File.open(manifest_file, "w") do |file|
        file.write buildpack_manifest_contents
      end

      File.open(sdk_tools_file, "w") do |file|
        file.write sdk_tools_contents
      end

      allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/dotnet-built.yml').and_return <<~COMMIT
        Build dotnet - #{new_version}

        ---
        filename: dotnet.#{new_version.gsub(/^v/,'')}.linux-amd64.tar.gz
        version: #{new_version}
        md5: aaaabbbb22224444
        sha256: newSHA256
      COMMIT
    end

    context 'the new dotnet sdk version is project.json' do
      let(:new_version)           { 'v1.0.0-preview2-009988' }

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview2-009988'}
        expect(dependency_in_manifest["version"]).to eq("1.0.0-preview2-009988")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-009988.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency}.count).to eq 5
      end

      it 'it is added to sdk tools file' do
        subject.run!
        sdk_tools = YAML.load_file(sdk_tools_file)

        expect(sdk_tools['project_json'].last).to eq '1.0.0-preview2-009988'
      end

      it "does not update the dotnet buildpack manifest dependency default with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview3-006666'}
        expect(default_in_manifest["version"]).to eq('1.0.0-preview3-006666')
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end

    context 'the new dotnet sdk version is msbuild' do
      let(:new_version)           { 'v1.0.0-preview4-001122' }

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview4-001122'}
        expect(dependency_in_manifest["version"]).to eq('1.0.0-preview4-001122')
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview4-001122.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end

      it "updates the dotnet buildpack manifest dependency default with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview4-001122'}
        expect(default_in_manifest["version"]).to eq('1.0.0-preview4-001122')
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency}.count).to eq 5
      end

      it 'it is added to sdk tools file' do
        subject.run!
        sdk_tools = YAML.load_file(sdk_tools_file)

        expect(sdk_tools['msbuild'].last).to eq '1.0.0-preview4-001122'
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end
  end
end
