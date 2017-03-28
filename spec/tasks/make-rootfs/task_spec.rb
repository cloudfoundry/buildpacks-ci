# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'make-rootfs' do
  cflinuxfs2_artifacts = 'spec/tasks/make-rootfs/cflinuxfs2-artifacts'
  receipt_artifacts = 'spec/tasks/make-rootfs/receipt-artifacts'

  before(:context) do
    Dir["#{cflinuxfs2_artifacts}/*"].each { |f| FileUtils.rm_rf f }
    Dir["#{receipt_artifacts}/*"].each { |f| FileUtils.rm_rf f }

    execute('-c tasks/make-rootfs/task.yml ' \
      '-p ' \
      '-i buildpacks-ci=. ' \
      '-i cflinuxfs2=spec/tasks/make-rootfs/cflinuxfs2 ' \
      '-i version=spec/tasks/make-rootfs/version ' \
      "-o cflinuxfs2-artifacts=#{cflinuxfs2_artifacts} " \
      "-o receipt-artifacts=#{receipt_artifacts} ")
  end

  it 'overwrites the correct buildpack .zip file' do
    expect(File.exist?("#{cflinuxfs2_artifacts}/cflinuxfs2-1.0.tar.gz")).to eq(true)
    expect(File.exist?("#{receipt_artifacts}/cflinuxfs2_receipt-1.0")).to eq(true)
  end
end
