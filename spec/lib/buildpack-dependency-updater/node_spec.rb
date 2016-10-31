# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_builds_dir)        { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }
  let(:manifest_file)            { File.join(buildpack_dir, "manifest.yml") }
  let(:dep_url)                  { "https://#{dependencies_host_domain}/path-to-built-binary" }
  let(:dependency)               { "node" }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_builds_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do

    before do
      allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
        Build node - #{expected_version}
        filename: binary-builder/node-#{expected_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
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
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-0.12.45-linux-x64.tgz
            md5: b6607379e8cdcfa3763acc12fe40cef9
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 0.12.46
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-0.12.46-linux-x64.tgz
            md5: 2e02c3350a0b81e8b501ef3ea637a93b
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 4.4.5
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-4.4.5-linux-x64.tgz
            md5: b2893ffdf42e2c3614872ced633feeea
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 4.4.6
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-4.4.6-linux-x64.tgz
            md5: 33822ae3f92ac9586d73dee3c42a4bf2
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 5.11.1
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-5.11.1-linux-x64.tgz
            md5: c6da910f661470d01e7920a1d3efaee2
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 5.12.0
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-5.12.0-linux-x64.tgz
            md5: 006d5be71aa68c7cccdd5c2c9f1d0fc0
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 6.2.1
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-6.2.1-linux-x64.tgz
            md5: 619a748a2b23f3e0189cf8c3f291b8d3
            cf_stacks:
              - cflinuxfs2
          - name: node
            version: 6.2.2
            uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-6.2.2-linux-x64.tgz
            md5: e54ef4e2637d8cc8125a8ccc67c47951
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
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '0.12.46'}
          expect(dependency_in_manifest["version"]).to eq("0.12.46")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-0.12.46-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("2e02c3350a0b81e8b501ef3ea637a93b")
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

      context("node >= 4") do
        let (:expected_version) { '4.5.0'}

        it "updates the nodejs buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.5'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.6'}
          expect(dependency_in_manifest["version"]).to eq("4.4.6")
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-4.4.6-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("33822ae3f92ac9586d73dee3c42a4bf2")
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
          expect(STDOUT).to receive(:puts).with('node 6.2.2 is already in the manifest for the nodejs buildpack.')
          expect(STDOUT).to receive(:puts).with('No updates will be made to the manifest or buildpack.')
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
              uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/node/node-4.4.4-linux-x64.tgz
              md5: 8beeb9a17a81b9832a1ccce02e6d6897
              cf_stacks:
                - cflinuxfs2
            - name: ruby
              version: 2.3.0
              md5: 535342030a11abeb11497824bf642bf2
              uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/ruby/ruby-2.3.0-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
            - name: ruby
              version: 2.3.1
              md5: c55c51d66a18123363e7f96635b54717
              uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/ruby/ruby-2.3.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
            - name: rails_log_stdout
              version: 0
              uri: https://pivotal-buildpacks.s3.amazonaws.com/ruby/binaries/lucid64/rails_log_stdout.tgz
              md5: 9ecd9126ba4a5f12ec98bc75c433885f
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
          expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/node/node-4.4.4-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("8beeb9a17a81b9832a1ccce02e6d6897")
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

      context("node >= 4") do
        let (:expected_version) { '4.5.0'}

        it "updates the ruby buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          version_hash = {"match"=>"node", "name"=>dependency, "version"=>expected_version}
          expect(manifest["url_to_dependency_map"]).to include(version_hash)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.4'}
          expect(dependency_in_manifest).to eq(nil)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(dependency_in_manifest["version"]).to eq(expected_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
        end

        it "updates the ruby buildpack manifest dependency default with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
          expect(default_in_manifest["version"]).to eq(expected_version)

          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '4.4.4'}
          expect(default_in_manifest).to eq(nil)
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['4.4.4'])
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
             uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003121.linux-amd64.tar.gz
             md5: 8496b07e910f3b7997196e23427f3676
           - name: dotnet
             version: 1.0.0-preview2-003131
             cf_stacks:
               - cflinuxfs2
             uri: https://buildpacks.cloudfoundry.org/concourse-binaries/dotnet/dotnet.1.0.0-preview2-003131.linux-amd64.tar.gz
             md5: 0abbf8aaae612c02aa529ca2a80d091a
           - name: node
             version: 6.9.0
             cf_stacks:
               - cflinuxfs2
             uri: https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-6.9.0-linux-x64.tgz
             md5: 6c1e3fcff5c9275206543d5a7fe92d57
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
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-6.9.0-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("6c1e3fcff5c9275206543d5a7fe92d57")
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
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/node/node-#{expected_version}-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
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
