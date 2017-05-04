# encoding: utf-8
require 'spec_helper.rb'
require 'yaml'
require 'tmpdir'
require_relative '../../../tasks/create-buildpack-bosh-release/buildpack-bosh-release-updater'

describe BuildpackBOSHReleaseUpdater do
  let(:version)           { '3.3.3' }
  let(:access_key_id)     { 'username' }
  let(:secret_access_key) { 'password' }
  let(:test_dir)          { Dir.mktmpdir }
  let(:release_dir)       { File.join(test_dir, 'bosh-release') }
  let(:buildpack_dir)       { File.join(test_dir, 'source') }
  let(:blob_name)         { 'test-buildpack' }
  let(:blob_glob)         { '../source/test_buildpack*.zip' }
  let(:release_name)      { 'test-buildpack' }
  let(:old_blobs) do
    <<~BLOBS
       ---
       thing-one/thing-one_1.1.1.zip:
         size: 123
         object_id: 123-456
         sha: abcdef
       test-buildpack/test_buildpack-cached-v2.1.2.zip:
         size: 789
         object_id: abc-def
         sha: 987654
       BLOBS
  end
  let(:new_blobs) do
    <<~BLOBS
       ---
       thing-one/thing-one_1.1.1.zip:
         size: 123
         object_id: 123-456
         sha: abcdef
       BLOBS
  end

  subject {
    described_class.new(
      version,
      access_key_id,
      secret_access_key,
      blob_name,
      blob_glob,
      release_name)
  }

  before do
    allow(subject).to receive(:puts)
    allow(subject).to receive(:system).and_return(true)

    allow(GitClient).to receive(:add_file)
    allow(GitClient).to receive(:safe_commit)

    FileUtils.mkdir(release_dir)
    FileUtils.mkdir(buildpack_dir)

    @current_dir = Dir.pwd
    Dir.chdir release_dir
    FileUtils.mkdir('config')
  end

  after do
    Dir.chdir @current_dir
    FileUtils.rm_rf(test_dir)
  end

  describe '#write_private_yml' do
    it 'logs a message ' do
      expect(subject).to receive(:puts).with('creating private.yml')
      subject.write_private_yml
    end

    it 'writes the access key and secret to private.yml' do
      subject.write_private_yml

      contents = YAML.load_file('config/private.yml')
      expect(contents['blobstore']['s3']['access_key_id']).to eq 'username'
      expect(contents['blobstore']['s3']['secret_access_key']).to eq 'password'
    end
  end

  context 'the release is a regular buildpack' do
    describe '#delete_old_blob' do
      before do
        File.write('config/blobs.yml', old_blobs)
      end

      it 'removes the old blob from blobs.yml' do
        subject.delete_old_blob

        blobs_contents = File.read('config/blobs.yml')
        expect(blobs_contents).to eq(new_blobs)
      end
    end

    describe '#add_new_blob' do
      before do
        File.write(File.join(buildpack_dir, 'test_buildpack-cached-v3.3.3.zip'), 'xxx')
      end

      it 'adds the blob and commits the yml' do
        expect(subject).to receive(:system).with("bosh -n add blob ../source/test_buildpack-cached-v3.3.3.zip test-buildpack")
        expect(subject).to receive(:system).with("bosh -n upload blobs")

        expect(GitClient).to receive(:add_file).with('config/blobs.yml')
        expect(GitClient).to receive(:safe_commit).with('Updating blobs for test-buildpack at 3.3.3')

        subject.add_new_blob
      end
    end

    describe '#create_release' do
      it 'creates the release and commits the generated files' do
        expect(subject).to receive(:system).with "bosh -n create release --final --version 3.3.3 --name test-buildpack --force"

        expect(GitClient).to receive(:add_file).with "releases/**/*-3.3.3.yml"
        expect(GitClient).to receive(:add_file).with "releases/**/index.yml"
        expect(GitClient).to receive(:add_file).with ".final_builds/**/index.yml"
        expect(GitClient).to receive(:add_file).with ".final_builds/**/**/index.yml"
        expect(GitClient).to receive(:safe_commit).with "Final release for test-buildpack at 3.3.3"

        subject.create_release
      end
    end
  end

  context 'the release is java-offline buildpack' do
    let(:blob_name)         { 'java-buildpack' }
    let(:blob_glob)         { '../source/java-buildpack-offline*.zip' }
    let(:release_name)      { 'java-offline-buildpack' }
    let(:old_blobs) do
      <<~BLOBS
         ---
         thing-one/thing-one_1.1.1.zip:
           size: 123
           object_id: 123-456
           sha: abcdef
         java-buildpack/java-buildpack-offline-v4.5.6.zip:
           size: 78910
           object_id: def-bac
           sha: really-a-sha
         BLOBS
    end

    describe '#delete_old_blob' do
      before do
        File.write('config/blobs.yml', old_blobs)
      end

      it 'removes the old blob from blobs.yml' do
        subject.delete_old_blob

        blobs_contents = File.read('config/blobs.yml')
        expect(blobs_contents).to eq(new_blobs)
      end
    end

    describe '#add_new_blob' do
      before do
        File.write(File.join(buildpack_dir, 'java-buildpack-offline-v3.3.3.zip'), 'xxx')
      end

      it 'adds the blob and commits the yml' do
        expect(subject).to receive(:system).with("bosh -n add blob ../source/java-buildpack-offline-v3.3.3.zip java-buildpack")
        expect(subject).to receive(:system).with("bosh -n upload blobs")

        expect(GitClient).to receive(:add_file).with('config/blobs.yml')
        expect(GitClient).to receive(:safe_commit).with('Updating blobs for java-offline-buildpack at 3.3.3')

        subject.add_new_blob
      end
    end

    describe '#create_release' do
      it 'creates the release and commits the generated files' do
        expect(subject).to receive(:system).with "bosh -n create release --final --version 3.3.3 --name java-offline-buildpack --force"

        expect(GitClient).to receive(:add_file).with "releases/**/*-3.3.3.yml"
        expect(GitClient).to receive(:add_file).with "releases/**/index.yml"
        expect(GitClient).to receive(:add_file).with ".final_builds/**/index.yml"
        expect(GitClient).to receive(:add_file).with ".final_builds/**/**/index.yml"
        expect(GitClient).to receive(:safe_commit).with "Final release for java-offline-buildpack at 3.3.3"

        subject.create_release
      end
    end
  end
end

