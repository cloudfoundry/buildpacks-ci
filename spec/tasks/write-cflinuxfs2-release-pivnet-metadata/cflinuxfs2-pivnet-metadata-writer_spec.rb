# encoding: utf-8
require 'tmpdir'
require 'fileutils'
require 'spec_helper.rb'
require 'yaml'
require_relative '../../../tasks/write-cflinuxfs2-release-pivnet-metadata/cflinuxfs2-pivnet-metadata-writer.rb'

describe Cflinuxfs2PivnetMetadataWriter do
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

  context 'the product is compilerless rootfs' do
    let(:yaml_name)                   { 'rootfs-nc' }
    let(:stack_version)               { '4.43'}
    let(:release_version)             { '7.2.1'}

    subject { described_class.new(metadata_dir, stack_version, release_version) }

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
        expect(release['file']).to eq 'files-to-upload/cflinuxfs2-nc-rootfs-7.2.1.tgz'
        expect(release['upload_as']).to eq 'BOSH release of Compilerless RootFS'
        expect(release['description']).to eq 'BOSH release of Compilerless RootFS for PCF'

        deployment_instructions = product_files.last
        expect(deployment_instructions['file']).to eq 'files-to-upload/README.md'
        expect(deployment_instructions['upload_as']).to eq 'Deployment Instructions'
        expect(deployment_instructions['description']).to eq 'Deployment instructions for the BOSH release of Compilerless RootFS for PCF'
      end
    end
  end
end
