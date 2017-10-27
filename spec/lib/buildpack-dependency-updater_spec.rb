# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)            { Dir.mktmpdir }
  let(:binary_built_out_dir)     { Dir.mktmpdir }
  let(:dependencies_host_domain) { 'buildpacks.cloudfoundry.org' }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_built_out_dir) }

  before { allow(ENV).to receive(:fetch).with('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil).and_return(dependencies_host_domain) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dep_url)       { "https://#{dependencies_host_domain}/path-to-built-binary" }

    context("godep") do
      let(:dependency)  { "godep" }
      let(:buildpack)   { "go" }
      let(:new_version) { "v65" }
      let(:new_sha256)  { "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03" }
      let(:existing_godep_version) { 'v64' }

      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: go
          dependencies:
            - name: go
              version: 1.6.2
              uri: https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
              sha256: e40c36ae71756198478624ed1bb4ce17597b3c19d243f3f0899bb5740d56212a
              cf_stacks:
                - cflinuxfs2
            - name: godep
              version: #{existing_godep_version}
              uri: https://buildpacks.cloudfoundry.org/dependencies/godep/godep-v64-linux-x64.tgz
              sha256: 205b60ee79914af6a09b897170b522c5e16366214b9a0735b4eb550f4b14a3c8
              cf_stacks:
                - cflinuxfs2
            - name: composer
              version: 1.a-thing
              uri: https://buildpacks.cloudfoundry.org/dependencies/godep/godep-v64-linux-x64.tgz
              sha256: 205b60ee79914af6a09b897170b522c5e16366214b9a0735b4eb550f4b14a3c8
              cf_stacks:
                - cflinuxfs2
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/godep-built.yml').and_return <<~COMMIT
          Build godep - #{new_version}

          ---
          filename: godep-#{new_version}-linux-x64.tgz
          version: #{new_version}
          md5: whatever
          sha256: #{new_sha256}
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        expect($stdout).to receive(:puts).with("Attempting to add godep v65 to the go buildpack and manifest.")
        subject.run!
        manifest = YAML.load_file(manifest_file)
        expect(manifest).not_to have_key("url_to_dependency_map")

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/godep/godep-#{new_version}-linux-x64.tgz")
        expect(dependency_in_manifest["sha256"]).to eq(new_sha256)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['v64'])
      end

      context "dependency version to add is older than one in manifest" do
        let(:new_version) { "v63" }
        let(:new_sha256)  { "50b413f0c8f28298a90ee91cbebf439e30af9050d55669df129a699607893d9e" }

        it "does not try to update the manifest or buildpack" do
          expect(subject).not_to receive(:perform_dependency_update)
          expect(subject).not_to receive(:perform_dependency_specific_changes)
          expect($stdout).to receive(:puts).with('godep v63 is older than the one in the manifest for the go buildpack.')
          expect($stdout).to receive(:puts).with('No updates will be made to the manifest or buildpack.')
          subject.run!
        end
      end

      context "dependency version is different to manifest, but neither godep or semver" do
        let(:existing_godep_version) { '1.a-this' }
        let(:new_version) { "2.b-that" }
        let(:new_sha256)  { "50b413f0c8f28298a90ee91cbebf439e30af9050d55669df129a699607893d9e" }

        it "updates the specified buildpack manifest dependency with the specified version" do
          expect($stdout).to receive(:puts).with("Attempting to add godep 2.b-that to the go buildpack and manifest.")
          subject.run!
        end
      end

      context "dependency version to add is already in manifest" do
        let(:new_version) { "v64" }
        let(:new_sha256)  { "205b60ee79914af6a09b897170b522c5e16366214b9a0735b4eb550f4b14a3c8" }

        it "does not try to update the manifest or buildpack" do
          expect(subject).not_to receive(:perform_dependency_update)
          expect(subject).not_to receive(:perform_dependency_specific_changes)
          expect($stdout).to receive(:puts).with('godep v64 is already in the manifest for the go buildpack.')
          expect($stdout).to receive(:puts).with('No updates will be made to the manifest or buildpack.')
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
              uri: https://buildpacks.cloudfoundry.org/dependencies/composer/composer-1.0.3-aff20443.phar
              cf_stacks:
                - cflinuxfs2
              sha256: 4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/composer-built.yml').and_return <<~COMMIT
          Build composer - #{new_version}

          ---
          filename: composer-#{new_version}-abcdef12.phar
          version: #{new_version}
          md5: whatever
          sha256: 7f26efee06de5a1a061b6b1e330f5acc9ee69976d1551118c45b21f358cbc332
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/composer/composer-1.1.0-abcdef12.phar")
        expect(dependency_in_manifest["sha256"]).to eq("7f26efee06de5a1a061b6b1e330f5acc9ee69976d1551118c45b21f358cbc332")
      end

      it "updates the php buildpack manifest default_versions section with the specified version for composer" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        old_default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.0.3'}
        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        current_default_version = default_in_manifest["version"]

        expect(old_default_in_manifest).to eq(nil)
        expect(current_default_version).to eq(new_version)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['1.0.3'])
      end
    end

    RSpec.shared_examples "updating dependency in buildpack" do
      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: #{buildpack}
          default_versions:
            - name: #{dependency}
              version: #{old_version}
          dependencies:
            - name: #{dependency}
              version: #{old_version}
              uri: https://buildpacks.cloudfoundry.org/dependencies/#{dependency}/#{dependency}-#{old_version}-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              sha256: 4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, "binary-built-output/#{dependency}-built.yml").and_return <<~COMMIT
          Build #{dependency} - #{new_version}

          ---
          filename: #{dependency}-#{new_version}-linux-x64.tgz
          version: #{new_version}
          md5: whatever
          sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        expect(manifest).to_not have_key("url_to_dependency_map")

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/#{dependency}/#{dependency}-#{new_version}-linux-x64.tgz")
        expect(dependency_in_manifest["sha256"]).to eq("7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31")
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq([old_version])
      end
    end

    %w(glide bundler dep).each do |dependency|
      context(dependency) do
        let(:dependency)  { dependency }
        let(:buildpack)   { "go" }
        let(:new_version) { "0.10.2" }
        let(:old_version) { "0.9.3" }

        it_should_behave_like "updating dependency in buildpack"
      end
    end

    context("nginx_staticfile") do
      let(:dependency) { "nginx" }
      let(:buildpack)  { "staticfile" }
      before do
        buildpack_manifest_contents = <<~MANIFEST
          ---
          language: staticfile
          default_versions:
            - name: nginx
              version: 1.11.1
          url_to_dependency_map:
            - match: nginx-(\d+\.\d+\.\d+)
              name: nginx
              version: $1
          dependencies:
            - name: nginx
              version: 1.11.1
              uri: https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.11.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              sha256: 4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/nginx-built.yml').and_return <<~COMMIT
          Build nginx - #{new_version}

          ---
          filename: nginx-#{new_version}-linux-x64.tgz
          version: #{new_version}
          md5: whatever
          sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      context "new version is mainline (odd minor version)" do
       let(:new_version)  { "1.11.2" }

        it "updates the specified buildpack manifest dependency with the specified version" do
          subject.run!
          manifest = YAML.load_file(manifest_file)
          version_hash = {"match"=>"nginx-(d+.d+.d+)", "name"=>dependency, "version"=>"$1"}
          expect(manifest["url_to_dependency_map"]).to include(version_hash)

          dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
          expect(dependency_in_manifest["version"]).to eq(new_version)
          expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.11.2-linux-x64.tgz")
          expect(dependency_in_manifest["sha256"]).to eq("7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31")
        end

        it "updates the staticfile buildpack manifest default_versions section with the specified version for nginx" do
          subject.run!
          manifest = YAML.load_file(manifest_file)

          old_default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.11.1'}
          default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
          current_default_version = default_in_manifest["version"]

          expect(old_default_in_manifest).to eq(nil)
          expect(current_default_version).to eq(new_version)
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
          version_hash = {"match"=>"nginx-(d+.d+.d+)", "name"=>dependency, "version"=>"$1"}
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
              uri: https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.10.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              sha256: 4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1
            - name: nginx
              version: 1.11.1
              uri: https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.11.1-linux-x64.tgz
              cf_stacks:
                - cflinuxfs2
              sha256: 4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1
        MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).with(binary_built_out_dir, 0, 'binary-built-output/nginx-built.yml').and_return <<~COMMIT
          Build nginx - #{new_version}

          ---
          filename: nginx-#{new_version}-linux-x64.tgz
          version: #{new_version}
          md5: whatever
          sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        expect(dependency_in_manifest["version"]).to eq(new_version)
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.11.2-linux-x64.tgz")
        expect(dependency_in_manifest["sha256"]).to eq("7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31")

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] != new_version}
        expect(dependency_in_manifest["version"]).to eq("1.10.1")
        expect(dependency_in_manifest["uri"]).to eq("https://buildpacks.cloudfoundry.org/dependencies/nginx/nginx-1.10.1-linux-x64.tgz")
        expect(dependency_in_manifest["sha256"]).to eq("4bc453b53cb3d914b45f4b250294236adba2c0e09ff6f03793949e7e39fd4cc1")
      end

      it "updates the php buildpack manifest default_versions section with the specified version for nginx" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        old_default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == '1.11.1'}
        default_in_manifest = manifest["default_versions"].find{|dep| dep["name"] == dependency && dep["version"] == new_version}
        current_default_version = default_in_manifest["version"]

        expect(old_default_in_manifest).to eq(nil)
        expect(current_default_version).to eq(new_version)
      end

      it 'records which versions were removed' do
        subject.run!
        expect(subject.removed_versions).to eq(['1.11.1'])
      end
    end
  end
end
