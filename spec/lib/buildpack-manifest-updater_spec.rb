# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../lib/buildpack-manifest-updater'

describe BuildpackManifestUpdater do
  let(:buildpack_dir)     { Dir.mktmpdir }
  let(:binary_builds_dir) { Dir.mktmpdir }

  subject { described_class.new(dependency, buildpack, buildpack_dir, binary_builds_dir) }

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
        allow(described_class).to receive(:get_dependency_info).and_return([expected_version, dep_url, "md5-mocked"])
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)
        version_hash = {"match"=>dependency, "name"=>dependency, "version"=>expected_version}
        expect(manifest["url_to_dependency_map"]).to include(version_hash)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/path-to-built-binary")
        expect(dependency_in_manifest["md5"]).to eq("md5-mocked")
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
        allow(described_class).to receive(:get_dependency_info).and_return([expected_version, dep_url, "md5-mocked"])
      end

      it "updates the specified buildpack manifest dependency with the specified version" do
        subject.run!
        manifest = YAML.load_file(manifest_file)

        dependency_in_manifest = manifest["dependencies"].find{|dep| dep["name"] == dependency}
        expect(dependency_in_manifest["version"]).to eq(expected_version)
        expect(dependency_in_manifest["uri"]).to eq("https://pivotal-buildpacks.s3.amazonaws.com/path-to-built-binary")
        expect(dependency_in_manifest["md5"]).to eq("md5-mocked")
      end
    end
 end
end
