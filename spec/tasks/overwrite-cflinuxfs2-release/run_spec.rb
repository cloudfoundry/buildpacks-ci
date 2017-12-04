# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'
require 'open3'

describe 'make-rootfs' do
  old_path = ENV.fetch('PATH', nil)
  old_rootfs_release = ENV.fetch('ROOTFS_RELEASE', nil)
  ci_path = Dir.pwd
  test_path = File.join(ci_path, '/spec/tasks/overwrite-cflinuxfs2-release')
  blobs_dir = File.join(test_path, 'cflinuxfs2-release/blobs')
  blob_destination = File.join(blobs_dir, 'rootfs/cflinuxfs2-1.49.0.tar.gz')

  before(:context) do
    ENV.store('PATH', "#{test_path}:#{old_path}")
    ENV.store('ROOTFS_RELEASE', 'cflinuxfs2')
  end

  after(:context) do
    ENV.store('PATH', old_path)
    ENV.store('ROOTFS_RELEASE',  old_rootfs_release)
    FileUtils.rm_rf File.dirname(blob_destination)
    FileUtils.rm_rf "#{ci_path}/spec/tasks/overwrite-cflinuxfs2-release/cflinuxfs2-release/use-dev-release-opsfile.yml"
  end

  RSpec.shared_examples 'creating artifacts to deploy release with updated rootfs' do
    it 'creates a release with a cflinuxfs2 package that uses the cflinuxfs2-*.tar.gz from stack-s3' do
      Dir.chdir("#{ci_path}/spec/tasks/overwrite-cflinuxfs2-release") do
        stdout, _, status = Open3.capture3("#{ci_path}/tasks/overwrite-cflinuxfs2-release/run.sh")
        expect(status).to be_success
        expect(stdout).to include("bosh create release with cflinuxfs2 blob with SHA1: 502dd7cbee209d399844bc6914f73c41bfa068ce")
      end
    end

    it 'generates an opsfile to use the version of cflinuxfs2 built' do
      Dir.chdir("#{ci_path}/spec/tasks/overwrite-cflinuxfs2-release") do
        stdout, _, status = Open3.capture3("#{ci_path}/tasks/overwrite-cflinuxfs2-release/run.sh")
        expect(status).to be_success
        expected_version = stdout.match(/version created: (.*)/)[1]
        expect(YAML.load(File.read("cflinuxfs2-release/use-dev-release-opsfile.yml"))).to eql([{
          "type" => "replace",
          "path" => "/releases/name=cflinuxfs2",
          "value" => {
            "name" => "cflinuxfs2",
            "version" => expected_version
          }
        }])
      end
    end

    it 'rsyncs to the artifacts dir at the very end' do
      Dir.chdir("#{ci_path}/spec/tasks/overwrite-cflinuxfs2-release") do
        stdout, _, status = Open3.capture3("#{ci_path}/tasks/overwrite-cflinuxfs2-release/run.sh")
        expect(status).to be_success
        expect(stdout.split("\n").last).to eql("rsynced from cflinuxfs2-release/ to cflinuxfs2-release-artifacts")
      end
    end
  end

  context 'when the blob file exists' do
    before do
      FileUtils.mkdir_p(File.dirname(blob_destination))
      File.write(blob_destination, "old-tarball")
    end

    it_should_behave_like 'creating artifacts to deploy release with updated rootfs'
  end

  context 'when the blob file does not exist' do
    before do
      # delete the rootfs directory to make sure we create it
      FileUtils.rm_rf File.dirname(blob_destination)
    end

    it_should_behave_like 'creating artifacts to deploy release with updated rootfs'
  end
end
