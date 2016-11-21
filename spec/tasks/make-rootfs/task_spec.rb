# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'make-rootfs' do
  stacks_artifacts = 'spec/tasks/make-rootfs/stacks-artifacts'
  receipt_artifacts = 'spec/tasks/make-rootfs/receipt-artifacts'

  before(:context) do
    Dir["#{stacks_artifacts}/*"].each { |f| FileUtils.rm_rf f }
    Dir["#{receipt_artifacts}/*"].each { |f| FileUtils.rm_rf f }

    execute('-c tasks/make-rootfs/task.yml ' \
      '-p ' \
      '-i buildpacks-ci=. ' \
      '-i stacks=spec/tasks/make-rootfs/stacks ' \
      '-i version=spec/tasks/make-rootfs/version ' \
      "-o stacks-artifacts=#{stacks_artifacts} " \
      "-o receipt-artifacts=#{receipt_artifacts} ")
  end

  it 'overwrites the correct buildpack .zip file' do
    expect(File.exist?("#{stacks_artifacts}/cflinuxfs2-1.0.tar.gz")).to eq(true)
    expect(File.exist?("#{receipt_artifacts}/cflinuxfs2_receipt-1.0")).to eq(true)
  end
end
