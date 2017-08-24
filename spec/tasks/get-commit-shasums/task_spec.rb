# encoding: utf-8
require 'spec_helper'

describe 'get-commit-shasums', :fly do
  before :context do
    @sha_artifacts = Dir.mktmpdir
    `git init ./spec/tasks/get-commit-shasums`
    execute("-c tasks/get-commit-shasums/task.yml -i buildpacks-ci=. -i buildpack-checksums=./spec/tasks/get-commit-shasums -i buildpack-artifacts=./spec/tasks/get-commit-shasums/pivotal-buildpacks-cached -o sha-artifacts=#{@sha_artifacts}")
  end
  after(:context) do
    FileUtils.rm_rf @sha_artifacts
  end

  it 'has a helpful commit message' do
    output, status = Open3.capture2('git log -- buildpack.zip.SHA256SUM.txt', :chdir => @sha_artifacts)
    expect(status).to be_success

    expect(output).to include 'SHA256SUM for buildpack.zip'
  end
end
