# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'make-rootfs' do
  old_path = ENV['PATH']
  old_rootfs_release = ENV['ROOTFS_RELEASE']
  ci_path = Dir.pwd
  test_path = File.join(ci_path, '/spec/tasks/overwrite-cflinuxfs2-rootfs-release')
  blobs_dir = File.join(test_path, 'cflinuxfs2-rootfs-release/blobs')
  blob_destination = File.join(blobs_dir, 'rootfs/cflinuxfs2-1.49.0.tar.gz')

  before(:context) do
    ENV['PATH'] = "#{test_path}:#{ENV['PATH']}"
    ENV['ROOTFS_RELEASE'] = 'cflinuxfs2'
  end

  after(:context) do
    ENV['PATH'] = old_path
    ENV['ROOTFS_RELEASE'] =  old_rootfs_release
  end

  RSpec.shared_examples 'creates_the_blob' do
    it 'moves cflinuxfs2-*.tar.gz file from stack-s3 to cflinuxfs2-rootfs-release/blobs/rootfs/cflinuxfs2-[currentversion].tar.gz' do
      Dir.chdir("#{ci_path}/spec/tasks/overwrite-cflinuxfs2-rootfs-release") do
        system("#{ci_path}/tasks/overwrite-cflinuxfs2-rootfs-release/run.sh")
      end
      expect(File.exist?(blob_destination)).to eq(true)
      expect(File.read(blob_destination)).to eq('new-tarball')
    end
  end

  context 'when the blob file exists' do
    before do
      `printf old-tarball > #{blob_destination}`
    end

    include_examples 'creates_the_blob'
  end

  context 'when the blob file does not exist' do
    before do
      # delete the rootfs directory to make sure we create it
      FileUtils.rm_rf File.dirname(blob_destination)
    end

    include_examples 'creates_the_blob'
  end
end
