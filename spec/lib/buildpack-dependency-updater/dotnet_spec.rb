# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_builds_dir)        { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create('dotnet', 'dotnet-core', buildpack_dir, binary_builds_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dependency)   { 'dotnet' }
    let(:buildpack)    { 'dotnet-core' }
    let(:versions_file) { File.join(buildpack_dir, 'dotnet-versions.yml') }

    before do
      File.open(manifest_file, "w") do |file|
        file.write buildpack_manifest_contents
      end

      File.open(versions_file, "w") do |file|
        file.write versions_contents
      end

      allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
        Build dotnet - #{new_version}
        filename: binary-builder/dotnet.#{new_version}.linux-amd64.tar.gz, md5: aaaabbbb22224444, sha256: zzzzzyyyy99998888
      COMMIT

      allow(subject).to receive(:get_framework_version).and_return new_framework_version
    end

    context 'the new dotnet version is LTS' do
      let(:new_version)           { '1.0.0' }
      let(:new_framework_version) { '1.0.3' }
      let(:buildpack_manifest_contents) do
       <<~MANIFEST
          ---
          language: dotnet-core
          default_versions:
            - name: dotnet
              version: 1.0.0-preview2-003121
          dependencies:
            - name: dotnet
              version: 1.0.0-preview2-003121
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003121.linux-amd64.tar.gz
              md5: 8496b07e910f3b7997196e23427f3676
            - name: dotnet
              version: 1.0.0-preview3-006666
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview3-006666.linux-amd64.tar.gz
              md5: 66666666666666666666666666666666
            - name: dotnet
              version: 1.0.0-preview1-002702
              cf_stacks:
                - cflinuxfs2
              uri: https://go.microsoft.com/fwlink/?LinkID=798405
              md5: 44d1dcae69a11976cfc6facc83b3aa49
            - name: dotnet
              version: 1.0.0-preview2-003131
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz
              md5: 0abbf8aaae612c02aa529ca2a80d091a
          MANIFEST
      end

      let(:versions_contents) do
      <<~VERSIONS
        ---
        - dotnet: 1.0.0-preview1-002702
          framework: 1.0.0-rc2-3002702
        - dotnet: 1.0.0-preview2-003121
          framework: 1.0.0
        - dotnet: 1.0.0-preview3-006666
          framework: 1.0.2
        - dotnet: 1.0.0-preview2-003131
          framework: 1.0.1
        VERSIONS
      end

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0'}
        expect(dependency_in_manifest["version"]).to eq("1.0.0")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0.linux-amd64.tar.gz")
        expect(dependency_in_manifest["md5"]).to eq("aaaabbbb22224444")
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency}.count).to eq 5
      end

      it 'does not remove a version from the dotnet-versions.yml' do
        subject.run!
        versions = YAML.load_file(versions_file)

        expect(versions.count).to eq 5
      end

      it "updates the dotnet buildpack manifest dependency default with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0'}
        expect(default_in_manifest["version"]).to eq('1.0.0')
      end

      it "updates the dotnet-versions.yml specified version and its framework version" do
        subject.run!
        versions = YAML.load_file(versions_file)

        dependency_in_versions = versions.find{|ver| ver["dotnet"] == '1.0.0'}
        expect(dependency_in_versions['dotnet']).to eq('1.0.0')
        expect(dependency_in_versions['framework']).to eq('1.0.3')
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end

    context 'the new dotnet framework version is prerelease' do
      let(:new_version)           { '1.0.0' }
      let(:new_framework_version) { '1.1.0-preview1-001100-00' }
      let(:buildpack_manifest_contents) do
       <<~MANIFEST
          ---
          language: dotnet-core
          default_versions:
          - name: dotnet
            version: 1.0.0-preview2-003131
          url_to_dependency_map:
          - match: dotnet\.(.*)\.linux-amd64\.tar\.gz
            name: dotnet
            version: "$1"
          dependencies:
          - name: dotnet
            version: 1.0.0-preview2-003121
            cf_stacks:
            - cflinuxfs2
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003121.linux-amd64.tar.gz
            md5: 8496b07e910f3b7997196e23427f3676
          - name: dotnet
            version: 1.0.0-preview2-003131
            cf_stacks:
            - cflinuxfs2
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz
            md5: 0abbf8aaae612c02aa529ca2a80d091a
          MANIFEST
      end

      let(:versions_contents) do
      <<~VERSIONS
         ---
         - dotnet: 1.0.0-preview2-003121
           framework: 1.0.0
         - dotnet: 1.0.0-preview2-003131
           framework: 1.0.1
        VERSIONS
      end

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0'}
        expect(dependency_in_manifest["version"]).to eq("1.0.0")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0.linux-amd64.tar.gz")
        expect(dependency_in_manifest["md5"]).to eq("aaaabbbb22224444")
      end

      it "does not update the dotnet buildpack manifest dependency default with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview2-003131'}
        expect(default_in_manifest["version"]).to eq('1.0.0-preview2-003131')
      end

      it "updates the dotnet-versions.yml specified version and its framework version" do
        subject.run!
        versions = YAML.load_file(versions_file)

        dependency_in_versions = versions.find{|ver| ver["dotnet"] == '1.0.0'}
        expect(dependency_in_versions['dotnet']).to eq('1.0.0')
        expect(dependency_in_versions['framework']).to eq('1.1.0-preview1-001100-00')
      end
    end
  end

  describe '#get_framework_version' do
    let(:dependency)   { "dotnet" }
    let(:buildpack)    { "dotnet-core" }
    let(:new_version)  { '1.0.2' }
    let(:temp_dir)     { Dir.mktmpdir }

    before do
      allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
        Build dotnet - #{new_version}
        filename: binary-builder/dotnet.#{new_version}.linux-amd64.tar.gz, md5: aaaabbbb22224444, sha256: zzzzzyyyy99998888
      COMMIT

      allow(Dir).to receive(:mktmpdir).and_return(temp_dir)

      FileUtils.mkdir_p(File.join(temp_dir, 'shared', 'Microsoft.NETCore.App', '1.0.4'))
      allow(subject).to receive(:system)
    end

    it 'downloads and untars the new dotnet version' do
      expect(subject).to receive(:system).with('curl https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.2.linux-amd64.tar.gz -o dotnet.tar.gz')
      expect(subject).to receive(:system).with('tar -xf dotnet.tar.gz')
      subject.get_dependency_info
      subject.get_framework_version
    end

    it 'determines the correct framework version' do
      subject.get_dependency_info
      expect(subject.get_framework_version).to eq('1.0.4')
    end

    it 'deletes the temporary directory' do
      subject.get_dependency_info
      subject.get_framework_version
      expect(Dir.exist?(temp_dir)).to eq(false)
    end
  end
end
