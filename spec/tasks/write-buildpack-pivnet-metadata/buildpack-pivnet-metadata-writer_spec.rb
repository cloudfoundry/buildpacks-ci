# encoding: utf-8
require 'tmpdir'
require 'fileutils'
require 'spec_helper.rb'
require 'yaml'
require_relative '../../../tasks/write-buildpack-pivnet-metadata/buildpack-pivnet-metadata-writer.rb'


describe BuildpackPivnetMetadataWriter do
  let(:buildpack) {'some_buildpack'}
  let(:root_dir) {Dir.mktmpdir}
  let(:buildpack_dir) {File.join(root_dir, 'buildpack-master')}
  let(:metadata_dir) {File.join(root_dir, 'pivnet-buildpack-metadata', 'pivnet-metadata')}
  let(:cached_buildpack_filenames) {
    ["pivotal-buildpacks-stack0/#{buildpack}_buildpack-cached-v#{version}+#{timestamp}.zip",
      "pivotal-buildpacks-stack1/#{buildpack}_buildpack-cached-cflinuxfs2-v#{version}+#{timestamp}.zip",
      "pivotal-buildpacks-stack2/#{buildpack}_buildpack-cached-some-stack-v#{version}+#{timestamp}.zip"]
  }
  let(:yaml_path) {File.join(metadata_dir, "#{buildpack}.yml")}
  let(:yaml_contents) {YAML.load_file(yaml_path)}
  let(:timestamp) {'1111111111'}
  let(:recent_changes_filename) {File.join(root_dir, 'buildpack-artifacts', 'RECENT_CHANGES')}
  let(:recent_changes) {'some_changes'}
  let(:lts_product) {'false'}

  before do
    FileUtils.mkdir_p(buildpack_dir)
    FileUtils.mkdir_p(metadata_dir)
    FileUtils.mkdir_p(File.join(root_dir, 'buildpack-artifacts'))
    File.write(recent_changes_filename, recent_changes)
  end

  after do
    FileUtils.rm_rf(root_dir)
  end

  subject {described_class.new(buildpack, metadata_dir, buildpack_dir, cached_buildpack_filenames, recent_changes_filename, lts_product)}

  describe '#get_version' do
    let(:version) {'1.6.0'}
    let(:version_file) {File.join(buildpack_dir, 'VERSION')}

    before {File.write(version_file, version)}

    it 'returns the buildpack version' do
      expect(subject.get_version).to eq('1.6.0')
    end
  end

  describe '#run!' do

    context 'the buildpack is dotnet core' do
      let(:version) {'1.0.0'}
      let(:buildpack) {'dotnet-core'}
      let(:recent_changes) {'.NET Core Buildpack for PCF'}

      before {allow(subject).to receive(:get_version).and_return(version)}

      it 'writes a yaml file' do
        subject.run!
        expect(File.exist? yaml_path).to be_truthy
      end

      it 'writes the release metadata to the file' do
        subject.run!
        release = yaml_contents['release']
        expect(release['version']).to eq '1.0.0'
        expect(release['release_type']).to eq 'Minor Release'
        expect(release['eula_slug']).to eq 'pivotal_software_eula'
        expect(release['release_notes_url']).to eq 'https://github.com/cloudfoundry/dotnet-core-buildpack/releases/tag/v1.0.0'
        # expect(release['availability']).to eq 'All Users'
        expect(release.has_key? 'eccn').to be_falsey
        expect(release.has_key? 'license_exception').to be_falsey
      end

      it 'writes the product files metadata to the file' do
        subject.run!
        product_files = yaml_contents['product_files']
        expect(product_files.count).to eq 3

        product_file = product_files[0]
        expect(product_file['file']).to eq File.join('pivotal-buildpacks-stack0', 'dotnet-core_buildpack-cached-v1.0.0+1111111111.zip')
        expect(product_file['upload_as']).to eq '.NET Core Buildpack (offline)'
        expect(product_file['description']).to eq '.NET Core Buildpack for PCF'
        product_file = product_files[1]
        expect(product_file['file']).to eq File.join('pivotal-buildpacks-stack1', 'dotnet-core_buildpack-cached-cflinuxfs2-v1.0.0+1111111111.zip')
        expect(product_file['upload_as']).to eq '.NET Core Buildpack cflinuxfs2 (offline)'
        expect(product_file['description']).to eq '.NET Core Buildpack for PCF'
        product_file = product_files[2]
        expect(product_file['file']).to eq File.join('pivotal-buildpacks-stack2', 'dotnet-core_buildpack-cached-some-stack-v1.0.0+1111111111.zip')
        expect(product_file['upload_as']).to eq '.NET Core Buildpack some-stack (offline)'
        expect(product_file['description']).to eq '.NET Core Buildpack for PCF'
      end
    end

    context 'the buildpack is php' do
      let(:version) {'1.23.45'}
      let(:buildpack) {'php'}
      let(:recent_changes) {'new php modules'}

      before {allow(subject).to receive(:get_version).and_return(version)}

      it 'capitalizes filenames correctly' do
        subject.run!
        release = yaml_contents['release']
        product_file = yaml_contents['product_files'].first

        expect(release['version']).to eq '1.23.45'
        expect(product_file['upload_as']).to eq 'PHP Buildpack (offline)'
      end
    end

    context 'the buildpack is nodejs' do
      let(:version) {'6.78.99'}
      let(:buildpack) {'nodejs'}
      let(:recent_changes) {'node security fixes'}

      before {allow(subject).to receive(:get_version).and_return(version)}

      it 'capitalizes filenames correctly' do
        subject.run!
        release = yaml_contents['release']
        product_file = yaml_contents['product_files'].first

        expect(release['version']).to eq '6.78.99'
        expect(product_file['upload_as']).to eq 'NodeJS Buildpack (offline)'
      end
    end

    context 'the buildpack is nginx' do
      let(:version) {'6.78.99'}
      let(:buildpack) {'nginx'}
      let(:recent_changes) {'nginx security fixes'}
      let(:cached_buildpack_filenames) {["pivotal-buildpacks-stack0/#{buildpack}_buildpack-cached-cflinuxfs2-v#{version}+#{timestamp}.zip"]}

      before {allow(subject).to receive(:get_version).and_return(version)}

      it 'capitalizes filenames correctly' do
        subject.run!
        release = yaml_contents['release']
        product_file = yaml_contents['product_files'].first

        expect(release['version']).to eq '6.78.99'
        expect(product_file['upload_as']).to eq 'NGINX Buildpack cflinuxfs2 (offline)'
      end
    end

    context 'the buildpack is ruby' do
      let(:version) {'1.7.45'}
      let(:buildpack) {'ruby'}
      let(:recent_changes) do
        <<~RECENT_CHANGES
        * Added a feature
          (https://www.pivotaltracker.com/story/show/130945067)

        * Updated a dependency
          (https://www.pivotaltracker.com/story/show/131225127)
        Packaged binaries:

        | name                       | version                  | cf_stacks  |
        |----------------------------|--------------------------|------------|
        | ruby                       | 2.1.8                    | cflinuxfs2 |
        | ruby                       | 2.1.9                    | cflinuxfs2 |

        Default binary versions:

        | name | version |
        |------|---------|
        | ruby | 2.3.1   |
        | node | 4.6.0   |
          * SHA256: 64d73148c0ae8704b266ae83d8863453982c2468195d39637d7cc53ea52d8c19
        RECENT_CHANGES
      end

      before {allow(subject).to receive(:get_version).and_return(version)}

      it 'writes a yaml file' do
        subject.run!
        expect(File.exist? yaml_path).to be_truthy
      end

      it 'writes the release metadata to the file' do
        subject.run!
        release = yaml_contents['release']
        expect(release['version']).to eq '1.7.45'
        expect(release['release_type']).to eq 'Minor Release'
        expect(release['eula_slug']).to eq 'pivotal_software_eula'
        expect(release['release_notes_url']).to eq 'https://github.com/cloudfoundry/ruby-buildpack/releases/tag/v1.7.45'
        # expect(release['availability']).to eq 'All Users'
        expect(release['eccn']).to eq '5D002'
        expect(release['license_exception']).to eq 'TSU'
      end

      it 'writes the product files metadata to the file' do
        subject.run!
        product_files = yaml_contents['product_files']
        expect(product_files.count).to eq 3

        product_file = product_files.first
        expect(product_file['file']).to eq File.join('pivotal-buildpacks-stack0', 'ruby_buildpack-cached-v1.7.45+1111111111.zip')
        expect(product_file['upload_as']).to eq 'Ruby Buildpack (offline)'
        expect(product_file['description']).to match /Added a feature/
        expect(product_file['description']).to match /Updated a dependency/
        expect(product_file['description']).to match /Packaged binaries:/
        expect(product_file['description']).to match /Default binary versions:/
        expect(product_file['description']).to match /SHA256:/
      end

      context 'when lts_product is true' do
        let(:yaml_path) {File.join(metadata_dir, "#{buildpack}-lts.yml")}
        let(:lts_product) {'true'}
        it 'returns the product name and version for the version property' do
          subject.run!
          release = yaml_contents['release']
          expect(release['version']).to eq 'Ruby 1.7.45'
        end
      end
    end
  end
end
