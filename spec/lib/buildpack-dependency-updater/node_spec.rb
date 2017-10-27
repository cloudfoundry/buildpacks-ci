# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_built_out_dir)     { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }
  let(:manifest_file)            { File.join(buildpack_dir, "manifest.yml") }
  let(:dep_url)                  { "https://#{dependencies_host_domain}/path-to-built-binary" }
  let(:dependency)               { "node" }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do

    before do
      allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/node-built.yml').and_return <<~COMMIT
        Build node - #{expected_version}

        ---
        filename: node-#{expected_version}-linux-x64.tgz
        version: #{expected_version}
        md5: newMD5
        sha256: newSHA256
      COMMIT
    end

    context "the buildpack is nodejs" do
      let(:buildpack) { "nodejs" }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: nodejs
          url_to_dependency_map:
          - match: node\/v(\d+\.\d+\.\d+)
            name: node
            version: $1
          default_versions:
          - name: node
            version: 4.4.6
          dependencies:
          - name: node
            version: 0.12.45
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-0.12.45-linux-x64.tgz
            sha256: oldSHA256_0_12_45
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 0.12.46
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-0.12.46-linux-x64.tgz
            sha256: oldSHA256_0_12_46
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 4.4.5
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-4.4.5-linux-x64.tgz
            sha256: oldSHA256_4_4_5
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 4.4.6
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-4.4.6-linux-x64.tgz
            sha256: oldSHA256_4_4_6
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 5.11.1
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-5.11.1-linux-x64.tgz
            sha256: oldSHA256_5_11_1
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 5.12.0
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-5.12.0-linux-x64.tgz
            sha256: oldSHA256_5_12_0
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 6.2.1
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-6.2.1-linux-x64.tgz
            sha256: oldSHA256_6_2_1
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 6.2.2
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-6.2.2-linux-x64.tgz
            sha256: oldSHA256_6_2_2
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 7.0.0
            uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-7.0.0-linux-x64.tgz
            sha256: oldSHA256_7_0_0
            cf_stacks:
              - cflinuxfs2
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end

      end

      context("node 0.12") do
        let (:expected_version) { '0.12.47'}

        it "updates the nodejs buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '0.12.45'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '0.12.46'}
          expect(dependency_in_manifest["version"]).to eq("0.12.46")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-0.12.46-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_0_12_46")
        end

        it "does not update the nodejs buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.6'}
          expect(default_in_manifest["version"]).to eq('4.4.6')

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest).to eq(nil)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['0.12.45'])
        end
      end

      context("there is only 1 mainline version of node in the manifest") do
        let (:expected_version) { '7.1.0' }

        it "updates the nodejs buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '7.0.0'}
          expect(dependency_in_manifest["version"]).to eq("7.0.0")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-7.0.0-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_7_0_0")
        end

        it "does not update the nodejs buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.6'}
          expect(default_in_manifest["version"]).to eq('4.4.6')

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest).to eq(nil)
        end

        it 'does not remove any dependencies' do
          subject.run!
          expect(subject.removed_versions).to eq([])
        end
      end

      context("node >= 4") do
        let (:expected_version) { '4.5.0'}

        it "updates the nodejs buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.5'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.6'}
          expect(dependency_in_manifest["version"]).to eq("4.4.6")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-4.4.6-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_4_4_6")
        end

        it "updates the nodejs buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.6'}
          expect(default_in_manifest).to eq(nil)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest["version"]).to eq(expected_version)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['4.4.5'])
        end
      end

      context "dependency version to add is already in manifest" do
        let(:expected_version) { "6.2.2" }

        it "does not try to update the manifest or buildpack" do
          expect(subject).not_to receive(:perform_dependency_update)
          expect(subject).not_to receive(:perform_dependency_specific_changes)
          expect($stdout).to receive(:puts).with('node 6.2.2 is already in the manifest for the nodejs buildpack.')
          expect($stdout).to receive(:puts).with('No updates will be made to the manifest or buildpack.')
          subject.run!
        end
      end
    end

    context "the buildpack is ruby" do
      let(:buildpack) { "ruby" }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: ruby
          default_versions:
            - name: ruby
              version: 2.3.0
            - name: node
              version: 4.4.4
          url_to_dependency_map:
            - match: ruby-(\d+\.\d+\.\d+)
              name: ruby
              version: $1
            - match: node
              name: node
              version: 4.4.4
          dependencies:
            - name: node
              version: 4.4.4
              uri: https://pivotal-buildpacks.s3.amazonaws.com/dependencies/node/node-4.4.4-linux-x64.tgz
              sha256: oldSHA256_4_4_4
              cf_stacks:
                - cflinuxfs2
            - name: node
              version: 6.10.0
              uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-6.10.0-linux-x64-a53e48a2.tgz
              sha256: oldSHA256_6_10_0
              cf_stacks:
              - cflinuxfs2
            - name: ruby
              version: 2.3.0
              sha256: oldSHA256_RUBY_2_3_0
              uri: https://pivotal-buildpacks.s3.amazonaws.com/dependencies/ruby/ruby-2.3.0-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
            - name: ruby
              version: 2.3.1
              sha256: oldSHA256_RUBY_2_3_1
              uri: https://pivotal-buildpacks.s3.amazonaws.com/dependencies/ruby/ruby-2.3.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
      end

      context("node 0.12") do
        let (:expected_version) { '0.12.47'}

        it "does not update the ruby buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)
          version_hash = {"match"=>"node", "name"=>dependency, "version"=>"4.4.4"}
          expect(manifest["url_to_dependency_map"]).to include(version_hash)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == "4.4.4"}
          expect(dependency_in_manifest["version"]).to eq("4.4.4")
          expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/dependencies/node/node-4.4.4-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_4_4_4")
        end

        it "does not update the ruby buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.4'}
          expect(default_in_manifest["version"]).to eq('4.4.4')

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest).to eq(nil)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq([])
        end
      end

      context("node = 4.x") do
        let (:expected_version) { '4.5.0'}

        it "updates the ruby buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          version_hash = {"match"=>"node", "name"=>dependency, "version"=>expected_version}

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.4'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['4.4.4'])
        end
      end

      context("node = 6.x") do
        let (:expected_version) { '6.11.0'}

        it "updates the ruby buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          version_hash = {"match"=>"node", "name"=>dependency, "version"=>expected_version}

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '6.10.0'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['6.10.0'])
        end
      end
    end

    context "the buildpack is dotnet-core" do
      let(:buildpack)    { "dotnet-core" }

      before(:each) do
        buildpack_manifest_contents = <<~MANIFEST
         ---
         language: dotnet-core

         default_versions:
           - name: dotnet
             version: 1.0.0-preview2-003131
           - name: node
             version: 6.9.0

         url_to_dependency_map:
           - match: dotnet\.(.*)\.linux-amd64\.tar\.gz
             name: dotnet
             version: $1
           - match: node(.*)(\d+\.\d+\.\d+)-linux-x64.tar.gz
             name: node
             version: $2

         dependencies:
           - name: dotnet
             version: 1.0.0-preview2-003121
             cf_stacks:
               - cflinuxfs2
             uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-003121.linux-amd64.tar.gz
             sha256: oldSHA256_dotnet_preview2
           - name: dotnet
             version: 1.0.0-preview2-003131
             cf_stacks:
               - cflinuxfs2
             uri: https://buildpacks.cloudfoundry.org/dependencies/dotnet/dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz
             sha256: oldSHA256_dotnet_preview1
           - name: node
             version: 6.9.0
             cf_stacks:
               - cflinuxfs2
             uri: https://buildpacks.cloudfoundry.org/dependencies/node/node-6.9.0-linux-x64.tgz
             sha256: oldSHA256_6_9_0
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
      end

      context("the new version of node is 0.12.47") do
        let (:expected_version) { '0.12.47'}

        it "does not add the new version to the buildpack manifest" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == "6.9.0"}
          expect(dependency_in_manifest["version"]).to eq("6.9.0")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-6.9.0-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("oldSHA256_6_9_0")
        end

        it "does not change the default node version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '6.9.0'}
          expect(default_in_manifest["version"]).to eq('6.9.0')

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest).to eq(nil)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq([])
        end
      end

      context("the new version of node is >= 6") do
        let (:expected_version) { '6.15.32'}

        it "adds the new version to the buildpack manifest" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '6.9.0'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("newSHA256")
        end

        it "updates the ruby buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest["version"]).to eq(expected_version)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '6.9.0'}
          expect(default_in_manifest).to eq(nil)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['6.9.0'])
        end
      end
    end
  end
end
