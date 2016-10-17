# encoding: utf-8
require 'tmpdir'
require 'fileutils'
require 'spec_helper.rb'
require 'yaml'
require_relative '../../lib/pivnet-metadata-writer.rb'


describe PivnetMetadataWriter do
  let(:root_dir)                  { Dir.mktmpdir }
  let(:metadata_dir)              { File.join(root_dir, 'pivnet-metadata') }
  let(:yaml_path)                 { File.join(metadata_dir, "#{yaml_name}.yml") }
  let(:yaml_contents)             { YAML.load_file(yaml_path) }

  before(:each) do
    FileUtils.mkdir_p(metadata_dir)
  end

  after(:each) do
    FileUtils.rm_rf(root_dir)
  end

  context 'the product is dotnet-core buildpack' do
    let(:yaml_name)                 { 'dotnet-core' }
    let(:buildpack_dir)             { File.join(root_dir, 'buildpack-master') }
    let(:cached_buildpack_filename) { 'dotnet-core_buildpack-cached-v1.0.0+1472744399.zip' }
    let(:version)                   { "1.0.0" }

    before do
      FileUtils.mkdir_p(buildpack_dir)
    end


    subject { described_class.create('DotNetCore', metadata_dir, buildpack_dir, cached_buildpack_filename) }

    describe '#get_version' do
      let(:version_file) { File.join(buildpack_dir, 'VERSION') }

      before { File.write(version_file, version) }

      it "returns the buildpack version" do
        expect(subject.get_version).to eq('1.0.0')
      end
    end

    describe '#run!' do

      before { allow(subject).to receive(:get_version).and_return(version) }

      it "writes a yaml file" do
        subject.run!
        expect(File.exist? yaml_path).to be_truthy
      end

      it "writes the release metadata to the file" do
        subject.run!
        release = yaml_contents['release']
        expect(release['version']).to eq '.NET Core 1.0.0 (BETA)'
        expect(release['release_type']).to eq 'Beta Release'
        expect(release['eula_slug']).to eq 'pivotal_beta_eula'
        expect(release['release_notes_url']).to eq "https://github.com/cloudfoundry-community/dotnet-core-buildpack/releases/tag/v1.0.0"
        expect(release['availability']).to eq 'Admins Only'
      end

      it 'writes the product files metadata to the file' do
        subject.run!
        product_files = yaml_contents['product_files']
        expect(product_files.count).to eq 1

        product_file = product_files.first
        expect(product_file['file']).to eq File.join('pivotal-buildpack-cached', cached_buildpack_filename)
        expect(product_file['upload_as']).to eq '.NET Core Buildpack BETA (offline)'
        expect(product_file['description']).to eq '.NET Core Buildpack BETA for PCF'
      end
    end
  end

  context 'the product is compilerless rootfs' do
    let(:yaml_name)                   { 'rootfs-nc' }
    let(:stack_version)               { '4.43'}
    let(:release_version)             { '7.2.1'}

    subject { described_class.create('RootfsNC', metadata_dir, stack_version, release_version) }

    describe '#run!' do
      it "writes a yaml file" do
        subject.run!
        expect(File.exist? yaml_path).to be_truthy
      end

      it 'writes the product files metadata to the file' do
        subject.run!
        product_files = yaml_contents['product_files']
        expect(product_files.count).to eq 2

        release = product_files.first
        expect(release['file']).to eq 'bosh-release-s3/cflinuxfs2-nc-rootfs-7.2.1.tgz'
        expect(release['upload_as']).to eq 'BOSH release of Compilerless RootFS'
        expect(release['description']).to eq 'BOSH release of Compilerless RootFS for PCF'

        deployment_instructions = product_files.last
        expect(deployment_instructions['file']).to eq 'cflinuxfs2-nc-rootfs-release/README.md'
        expect(deployment_instructions['upload_as']).to eq 'Deployment Instructions'
        expect(deployment_instructions['description']).to eq 'Deployment instructions for the BOSH release of Compilerless RootFS for PCF'
      end
    end
  end
end
