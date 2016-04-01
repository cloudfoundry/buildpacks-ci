# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'make-rootfs' do
  old_path = ENV['PATH']
  ci_path = Dir.pwd
  test_path = File.join(ci_path, "/spec/scripts/stacks/overwrite-cflinuxfs2-rootfs-release")
  before(:context) do
    ENV['PATH'] = "#{test_path}:#{ENV['PATH']}"
  end

  after(:context) do
    ENV['PATH'] = old_path
    `printf old-tarball > #{test_path}/cflinuxfs2-rootfs-release/blobs/rootfs/cflinuxfs2-1.31.0.tar.gz`
    `printf new-tarball > #{test_path}/stack-s3/cflinuxfs2-9.9.tar.gz`
  end

  it 'moves cflinuxfs2-*.tar.gz file from stack-s3 to cflinuxfs2-rootfs-release/blobs/rootfs/cflinuxfs2-[currentversion].tar.gz' do
    Dir.chdir("#{ci_path}/spec/scripts/stacks/overwrite-cflinuxfs2-rootfs-release") do
      `#{ci_path}/scripts/stacks/overwrite-cflinuxfs2-rootfs-release`
    end
    expect(File.read(Dir["#{ci_path}/spec/**/cflinuxfs2-1.31.0.tar.gz"][0])).to eq('new-tarball')
  end
end
