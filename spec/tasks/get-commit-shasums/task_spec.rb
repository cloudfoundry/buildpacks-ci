# encoding: utf-8
require 'spec_helper'

describe 'get-commit-shasums' do
  before :context do
    `git init ./spec/tasks/get-commit-shasums`
    execute('-c tasks/get-commit-shasums/task.yml -i buildpacks-ci=. -i buildpack-checksums=./spec/tasks/get-commit-shasums -i buildpack-artifacts=./spec/tasks/get-commit-shasums/pivotal-buildpacks-cached')
  end

  it 'has a helpful commit message' do
    output = run('cd /tmp/build/*/sha-artifacts && git log -- buildpack.zip.SHA256SUM.txt')
    expect(output).to include 'SHA256SUM for buildpack.zip'
  end
end
