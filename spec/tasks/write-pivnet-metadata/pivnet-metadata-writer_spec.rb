# encoding: utf-8
require 'tmpdir'
require 'fileutils'
require 'spec_helper.rb'
require 'yaml'
require_relative '../../../tasks/write-pivnet-metadata/pivnet-metadata-writer.rb'


describe PivnetMetadataWriter do
  let(:root_dir)                  { Dir.mktmpdir }
  let(:buildpack_dir)             { File.join(root_dir, 'buildpack-master') }
  let(:metadata_dir)              { File.join(root_dir, 'pivnet-dotnet-core-metadata', 'pivnet-metadata') }
  let(:cached_buildpack_filename) { 'dotnet-core_buildpack-cached-v1.0.0+1472744399.zip' }
  let(:yaml_path)                 { File.join(metadata_dir, 'dotnet-core.yml') }
  let(:yaml_contents)             { YAML.load_file(yaml_path) }
  let(:version)                   { "1.0.0" }

  before do
    FileUtils.mkdir_p(buildpack_dir)
    FileUtils.mkdir_p(metadata_dir)
  end

  after do
    FileUtils.rm_rf(root_dir)
  end

  subject { described_class.new(metadata_dir, buildpack_dir, cached_buildpack_filename) }

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
