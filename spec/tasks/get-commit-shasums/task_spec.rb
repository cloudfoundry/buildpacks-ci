# encoding: utf-8
require 'spec_helper'

describe 'get-commit-shasums', :fly do
  before :context do
    @sha_artifacts = Dir.mktmpdir
    @buildpack_checksums = Dir.mktmpdir
    `rsync -a ./spec/tasks/get-commit-shasums/ #{@buildpack_checksums}/`
    `git init #{@buildpack_checksums}`
    execute("-c tasks/get-commit-shasums/task.yml --include-ignored -i buildpacks-ci=. -i buildpack-checksums=#{@buildpack_checksums} -i buildpack-artifacts=#{@buildpack_checksums}/pivotal-buildpacks-cached -o sha-artifacts=#{@sha_artifacts}")
  end
  after(:context) do
    FileUtils.rm_rf @sha_artifacts
    FileUtils.rm_rf @buildpack_checksums
  end

  it 'has a helpful commit message' do
    output, status = Open3.capture2('git log -- buildpack.zip.SHA256SUM.txt', :chdir => @sha_artifacts)
    expect(status).to be_success

    expect(output).to include 'SHA256SUM for buildpack.zip'
  end
end
