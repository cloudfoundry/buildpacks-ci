# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'make-rootfs', :fly do
  before(:context) do
    @cflinuxfs2_artifacts = Dir.mktmpdir
    @receipt_artifacts = Dir.mktmpdir

    execute('-c tasks/make-rootfs-cflinuxfs2/task.yml ' \
      '-p ' \
      '-i buildpacks-ci=. ' \
      '-i cflinuxfs2=spec/tasks/make-rootfs-cflinuxfs2/cflinuxfs2 ' \
      '-i version=spec/tasks/make-rootfs-cflinuxfs2/version ' \
      "-o cflinuxfs2-artifacts=#{@cflinuxfs2_artifacts} " \
      "-o receipt-artifacts=#{@receipt_artifacts} ")
  end
  after(:context) do
    FileUtils.rm_rf @cflinuxfs2_artifacts
    FileUtils.rm_rf @receipt_artifacts
  end

  it 'overwrites the correct buildpack .zip file' do
    expect(File.exist?("#{@cflinuxfs2_artifacts}/cflinuxfs2-1.0.tar.gz")).to eq(true)
    expect(File.exist?("#{@receipt_artifacts}/cflinuxfs2_receipt-1.0")).to eq(true)
  end
end
