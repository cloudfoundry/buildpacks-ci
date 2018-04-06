# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir) { Dir.mktmpdir }
  let(:previous_buildpack_dir) { Dir.mktmpdir }
  let(:binary_built_out_dir) { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create('dotnet', 'dotnet-core', buildpack_dir, previous_buildpack_dir, binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:previous_manifest_file) { File.join(previous_buildpack_dir, "manifest.yml") }
    let(:dependency) { 'dotnet' }
    let(:buildpack) { 'dotnet-core' }
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

    let(:previous_buildpack_manifest_contents) do
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

      File.open(previous_manifest_file, "w") do |file|
        file.write previous_buildpack_manifest_contents
      end

      File.open(sdk_tools_file, "w") do |file|
        file.write sdk_tools_contents
      end

      allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/dotnet-built.yml').and_return <<~COMMIT
        Build dotnet - #{new_version}

        ---
        filename: dotnet.#{new_version.gsub(/^v/, '')}.linux-amd64.tar.gz
        version: #{new_version}
        md5: aaaabbbb22224444
        sha256: newSHA256
      COMMIT
    end

    context 'the new dotnet sdk version is project.json' do
      let(:new_version) { 'v1.0.0-preview2-009988' }

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview2-009988' }
        expect(dependency_in_manifest["version"]).to eq("1.0.0-preview2-009988")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-009988.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency }.count).to eq 5
      end

      it "does not update the dotnet buildpack manifest dependency default with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview3-006666' }
        expect(default_in_manifest["version"]).to eq('1.0.0-preview3-006666')
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end

    context "when the latest release of dotnet in the previous manifest is the oldest version in the new manifest" do
      let(:new_version) { 'v1.0.3' }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: dotnet-core
          default_versions:
            - name: dotnet
              version: 1.0.1
          dependencies:
            - name: dotnet
              version: 1.0.1
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.1.linux-amd64.tar.gz
              sha256: oldSHA256_101
            - name: dotnet
              version: 1.0.2
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.2.linux-amd64.tar.gz
              sha256: oldSHA256_102
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end

        previous_buildpack_manifest_contents = <<~MANIFEST
          ---
          language: dotnet-core
          default_versions:
            - name: dotnet
              version: 1.0.0
          dependencies:
            - name: dotnet
              version: 1.0.0
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0.linux-amd64.tar.gz
              sha256: oldSHA256_100
            - name: dotnet
              version: 1.0.1
              cf_stacks:
                - cflinuxfs2
              uri: https://buildpacks.cloudfoundry1.org/dependencies/dotnet/dotnet.1.0.1.linux-amd64.tar.gz
              sha256: oldSHA256_101
        MANIFEST
        File.open(previous_manifest_file, "w") do |file|
          file.write previous_buildpack_manifest_contents
        end
      end

      it "keeps the latest release from the previous manifest" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        # Keep version from last release
        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.1' }
        expect(dependency_in_manifest["version"]).to eq("1.0.1")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.1.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_101")

        # Remove old version from last release & intermediate version
        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.0' }
        expect(dependency_in_manifest).to eq(nil)
        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.2' }
        expect(dependency_in_manifest).to eq(nil)

        # Add expected version
        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.3' }
        expect(dependency_in_manifest["version"]).to eq("1.0.3")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.3.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end
    end

    context 'the new dotnet sdk version is msbuild' do
      let(:new_version) { 'v1.0.0-preview4-001122' }

      it "updates the dotnet buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find { |dep| dep["name"] == dependency && dep["version"] == '1.0.0-preview4-001122' }
        expect(dependency_in_manifest["version"]).to eq('1.0.0-preview4-001122')
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview4-001122.linux-amd64.tar.gz")
        expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
      end

      context 'the default version of the dotnet sdk is lower than the specified version' do
        let(:buildpack_manifest_contents) do
          <<~MANIFEST
            ---
            language: dotnet-core
            default_versions:
              - name: dotnet
                version: 1.0.0
            dependencies: []
          MANIFEST
        end
        let(:new_version) { '1.2.3' }
        it "updates the dotnet buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find { |dep| dep["name"] == dependency }
          expect(default_in_manifest["version"]).to eq('1.2.3')
        end
      end

      context 'the default version is a wildcard and the specified version does NOT match' do
        let(:buildpack_manifest_contents) do
          <<~MANIFEST
            ---
            language: dotnet-core
            default_versions:
              - name: dotnet
                version: 1.x
            dependencies: []
          MANIFEST
        end
        let(:new_version) { '2.2.2' }
        it "updates the dotnet buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find { |dep| dep["name"] == dependency }
          expect(default_in_manifest["version"]).to eq('2.2.2')
        end
      end

      context 'the default version is a wildcard and the specified version matches' do
        let(:buildpack_manifest_contents) do
          <<~MANIFEST
            ---
            language: dotnet-core
            default_versions:
              - name: dotnet
                version: 1.x
            dependencies: []
          MANIFEST
        end
        let(:new_version) { '1.2.2' }
        it "does NOT update the dotnet buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find { |dep| dep["name"] == dependency }
          expect(default_in_manifest["version"]).to eq('1.x')
        end
      end

      context 'the default version of the dotnet sdk is higher than the specified version' do
        let(:buildpack_manifest_contents) do
          <<~MANIFEST
            ---
            language: dotnet-core
            default_versions:
              - name: dotnet
                version: 1.2.3
            dependencies: []
          MANIFEST
        end
        let(:new_version) { '1.0.0' }
        it "does NOT update the dotnet buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find { |dep| dep["name"] == dependency }
          expect(default_in_manifest["version"]).to eq('1.2.3')
        end
      end

      it 'does not remove a version from the manifest' do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        expect(manifest['dependencies'].select { |d| d['name'] == dependency }.count).to eq 5
      end

      it 'records that no versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([])
      end
    end
  end
end
