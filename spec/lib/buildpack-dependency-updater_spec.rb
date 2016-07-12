# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../lib/buildpack-dependency-updater'

describe BuildpackDependencyUpdater do
  let(:buildpack_dir)     { Dir.mktmpdir }
  let(:binary_builds_dir) { Dir.mktmpdir }

  subject { described_class.create(dependency, buildpack, buildpack_dir, binary_builds_dir) }

  describe '#run!' do
    let(:manifest_file) { File.join(buildpack_dir, "manifest.yml") }
    let(:dep_url)       { "https://pivotal-buildpacks.s3.amazonaws.com/path-to-built-binary" }

    context("godep") do
      let(:dependency)        { "godep" }
      let(:buildpack)         { "go" }
      let(:expected_version)  { "v65" }
      before do
        buildpack_manifest_contents = <<-MANIFEST
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
    uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/godep/godep-v65-linux-x64.tgz
    md5: f75da3a0c5ec08514ec2700c2a6d1187
    cf_stacks:
      - cflinuxfs2
MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<-COMMIT
Build godep - #{expected_version}
filename: binary-builder/godep-#{expected_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>expected_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/godep/godep-v65-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
      end
    end

    context("composer") do
      let(:dependency)        { "composer" }
      let(:buildpack)         { "php" }
      let(:expected_version)  { "1.1.0" }
      before do
        buildpack_manifest_contents = <<-MANIFEST
---
language: php
url_to_dependency_map:
  - match: "([^\/]*)-(\d+\.\d+\.\d+)"
    name: "$1"
    version: "$2"
  - match: "\/composer\/(.*)\/composer.phar"
    name: composer
    version: "$1"
dependencies:
  - name: composer
    version: 1.0.3
    uri: https://pivotal-buildpacks.s3.amazonaws.com/php/binaries/trusty/composer/1.1.0/composer.phar
    cf_stacks:
      - cflinuxfs2
    md5: aff20443a474112755ff0ef65c4873e5
MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<-COMMIT
Build composer - #{expected_version}
filename: binary-builder/composer-#{expected_version}.phar, md5: 05d30d20be1c94c9edc02756420a7d10, sha256: 7f26efee06de5a1a061b6b1e330f5acc9ee69976d1551118c45b21f358cbc332
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/php/binaries/trusty/composer/1.1.0/composer.phar")
        expect(dependency_in_manifest["md5"]).to eq("05d30d20be1c94c9edc02756420a7d10")
      end
    end

    context("glide") do
      let(:dependency)        { "glide" }
      let(:buildpack)         { "go" }
      let(:expected_version)  { "0.10.2" }
      before do
        buildpack_manifest_contents = <<-MANIFEST
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
    uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/glide/glide-0.9.3-linux-x64.tgz
    cf_stacks:
      - cflinuxfs2
    md5: aff20443a474112755ff0ef65c4873e5
MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<-COMMIT
Build glide - #{expected_version}
filename: binary-builder/glide-#{expected_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>expected_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/glide/glide-0.10.2-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
      end
    end

    context("nginx_staticfile") do
      let(:dependency)        { "nginx" }
      let(:buildpack)         { "staticfile" }
      let(:expected_version)  { "1.11.2" }
      before do
        buildpack_manifest_contents = <<-MANIFEST
---
language: staticfile

url_to_dependency_map:
  - match: nginx
    name: nginx
    version: 1.11.1

dependencies:
  - name: nginx
    version: 1.11.1
    uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.11.1-linux-x64.tgz
    cf_stacks:
      - cflinuxfs2
    md5: 7d28497395b62221f3380e82f89cd197
MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<-COMMIT
Build glide - #{expected_version}
filename: binary-builder/nginx-#{expected_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>expected_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.11.2-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")
      end
    end

    context("nginx_php") do
      let(:dependency)        { "nginx" }
      let(:buildpack)         { "php" }
      let(:expected_version)  { "1.11.2" }
      let(:defaults_options_file) { File.join(buildpack_dir, "defaults/options.json") }

      before do
        buildpack_manifest_contents = <<-MANIFEST
---
language: php

dependencies:
  - name: nginx
    version: 1.10.1
    uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.10.1-linux-x64.tgz
    cf_stacks:
      - cflinuxfs2
    md5: 7d28497395b62221f3380e82f89cd197
  - name: nginx
    version: 1.11.1
    uri: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.11.1-linux-x64.tgz
    cf_stacks:
      - cflinuxfs2
    md5: 7d28497395b62221f3380e82f89cd197
MANIFEST
        File.open(manifest_file, "w") do |file|
          file.write buildpack_manifest_contents
        end
        allow(GitClient).to receive(:last_commit_message).and_return <<-COMMIT
Build glide - #{expected_version}
filename: binary-builder/nginx-#{expected_version}-linux-x64.tgz, md5: 18bec8f65810786c846d8b21fe73064f, sha256: 7f69c7b929e6fb5288e72384f8b0cd01e32ac2981a596e730e38b01eb8f2ed31
        COMMIT

        buildpack_defaults_options_json = <<-OPTIONS_JSON
{
    "NGINX_VERSION": "{NGINX_1_11_LATEST}",
    "NGINX_1_11_LATEST": "1.11.1",
    "OTHER_STUFF_WE_DONT_CARE_ABOUT": "IN THIS TEST"
}
OPTIONS_JSON
        FileUtils.mkdir_p(File.join(buildpack_dir, "defaults"))
        File.write(defaults_options_file, buildpack_defaults_options_json)
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] == expected_version}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.11.2-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("18bec8f65810786c846d8b21fe73064f")

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency && dep["version"] != expected_version}
        expect(dependency_in_manifest["version"]).to eq("1.10.1")
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/nginx/nginx-1.10.1-linux-x64.tgz")
        expect(dependency_in_manifest["md5"]).to eq("7d28497395b62221f3380e82f89cd197")
      end

      it "updates the php buildpack default nginx version configuration" do
        subject.run!

        defaults_options = JSON.parse(File.read(defaults_options_file))
        expect(defaults_options['NGINX_1_11_LATEST']).to eq('1.11.2')
      end
    end
  end
end
