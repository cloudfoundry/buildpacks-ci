# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_builds_dir)        { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_builds_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dep_url)       { "https://#{dependencies_host_domain}/path-to-built-binary" }

    context("godep") do
      let(:dependency)  { "godep" }
      let(:buildpack)   { "go" }
      let(:new_version) { "v65" }
      let(:new_md5)     { "18bec8f65810786c846d8b21fe73064f" }

      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: go
          url_to_dependency_map:
            - match: go(\d+\.\d+(.*))
              name: go
              version: $1
            - match: godep
              name: godep
              version: v64
          dependencies:
            - name: go
              version: 1.6.2
              uri: https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
              md5: ebfb8b38330c8779b121c43433c4b9be
              cf_stacks:
                - cflinuxfs2
            - name: godep
              version: v64
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/godep/godep-v64-linux-x64.tgz
              md5: f75da3a0c5ec08514ec2700c2a6d1187
              cf_stacks:
                - cflinuxfs2
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
          Build godep - #{new_version}
          filename: binary-builder/godep-#{new_version}-linux-x64.tgz, md5: #{new_md5}, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        expect(STDOUT).to receive(:puts).with("Attempting to add godep v65 to the go buildpack and manifest.")
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>new_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/godep/godep-#{new_version}-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq(new_md5)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['v64'])
      end

      context "dependency version to add is already in manifest" do
        let(:new_version) { "v64" }
        let(:new_md5)     { "f75da3a0c5ec08514ec2700c2a6d1187" }

        it "does not try to update the manifest or buildpack" do
          expect(subject).not_to receive(:perform_dependency_update)
          expect(subject).not_to receive(:perform_dependency_specific_changes)
          expect(STDOUT).to receive(:puts).with('godep v64 is already in the manifest for the go buildpack.')
          expect(STDOUT).to receive(:puts).with('No updates will be made to the manifest or buildpack.')
          subject.run!
        end
      end
    end

    context("composer") do
      let(:dependency)   { "composer" }
      let(:buildpack)    { "php" }
      let(:new_version)  { "1.1.0" }
      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: php
          url_to_dependency_map:
            - match: "([^\/]*)-(\d+\.\d+\.\d+)"
              name: "$1"
              version: "$2"
            - match: "\/composer\/(.*)\/composer.phar"
              name: composer
              version: "$1"
          default_versions:
            - name: composer
              version: 1.0.3
          dependencies:
            - name: composer
              version: 1.0.3
              uri: https://buildpacks.cloudfoundry.org/php/binaries/trusty/composer/1.1.0/composer.phar
              cf_stacks:
                - cflinuxfs2
              md5: aff20443a474112755ff0ef65c4873e5
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
          Build composer - #{new_version}
          filename: binary-builder/composer-#{new_version}.phar, md5: 05d30d20be1c94c9edc02756420a7d10, sha256: 7f26efee06de5a1a061b6b1e330f5acc9ee69976d1551118c45b21f358cbc332
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/php/binaries/trusty/composer/1.1.0/composer.phar")
        expect(dependency_in_manifest["md5"]).to eq("05d30d20be1c94c9edc02756420a7d10")
      end

      it "updates the php buildpack manifest default_versions section with the specified version for composer" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.3'}
        expect(default_in_manifest).to eq(nil)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        expect(default_in_manifest["version"]).to eq(new_version)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['1.0.3'])
      end
    end

    context("glide") do
      let(:dependency)  { "glide" }
      let(:buildpack)   { "go" }
      let(:new_version) { "0.10.2" }
      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: go
          url_to_dependency_map:
          - match: go(\d+\.\d+(.*))
            name: go
            version: "$1"
          - match: glide
            name: glide
            version: 0.9.3
          dependencies:
            - name: glide
              version: 0.9.3
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/glide/glide-0.9.3-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              md5: aff20443a474112755ff0ef65c4873e5
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
          Build glide - #{new_version}
          filename: binary-builder/glide-#{new_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>new_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/glide/glide-0.10.2-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['0.9.3'])
      end
    end

    context("nginx_staticfile") do
      let(:dependency) { "nginx" }
      let(:buildpack)  { "staticfile" }
      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: staticfile

          url_to_dependency_map:
            - match: nginx.tgz
              name: nginx
              version: 1.11.1

          dependencies:
            - name: nginx
              version: 1.11.1
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.11.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              md5: 7d28497395b62221f3380e82f89cd197
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
          Build nginx - #{new_version}
          filename: binary-builder/nginx-#{new_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      context "new version is mainline (odd minor version)" do
       let(:new_version)  { "1.11.2" }

        it "updates the specified buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)
          version_hash = {"match"=>"nginx.tgz", "name"=>dependency, "version"=>new_version}
          expect(manifest["url_to_dependency_map"]).to include(version_hash)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
          expect(dependency_in_manifest["version"]).to eq(new_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.11.2-linux-x64.tgz")
          expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq(['1.11.1'])
        end
      end

      context "new version is stable (even minor version)" do
       let(:new_version)  { "1.10.2" }

        it "does not update the specified buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)
          version_hash = {"match"=>"nginx.tgz", "name"=>dependency, "version"=>"1.11.1"}
          expect(manifest["url_to_dependency_map"]).to include(version_hash)

          new_dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
          expect(new_dependency_in_manifest).to be_nil
        end

        it 'records which versions were removed' do
          subject.run!
          expect(subject.removed_versions).to eq([])
        end
      end
    end

    context("nginx_php") do
      let(:dependency)   { "nginx" }
      let(:buildpack)    { "php" }
      let(:new_version)  { "1.11.2" }
      let(:defaults_options_file) { File.join(buildpack_dir, "defaults/options.json") }

      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: php
          default_versions:
            - name: nginx
              version: 1.11.1
          dependencies:
            - name: nginx
              version: 1.10.1
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.10.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              md5: 7d28497395b62221f3380e82f89cd197
            - name: nginx
              version: 1.11.1
              uri: https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.11.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              md5: 7d28497395b62221f3380e82f89cd197
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<~COMMIT
          Build nginx - #{new_version}
          filename: binary-builder/nginx-#{new_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.11.2-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] != new_version}
        expect(dependency_in_manifest["version"]).to eq("1.10.1")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/concourse-binaries/nginx/nginx-1.10.1-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("7d28497395b62221f3380e82f89cd197")
      end

      it "updates the php buildpack manifest default_versions section with the specified version for nginx" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.11.1'}
        expect(default_in_manifest).to eq(nil)

        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        expect(default_in_manifest["version"]).to eq(new_version)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['1.11.1'])
      end
    end
  end
end
