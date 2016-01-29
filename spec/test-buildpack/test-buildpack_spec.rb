# encoding: utf-8
require 'spec_helper.rb'

describe 'test-buildpack task' do
  before(:context) do
    execute('-c tasks/test-buildpack.yml ' \
            '-p ' \
            '-i buildpacks-ci=. -i buildpack=./spec/test-buildpack ' \
            '-i deployments-buildpacks=./spec/test-buildpack ' \
            '-i cf-environments=./spec/test-buildpack',               'DEPLOYMENT_NAME' => 'test',
                                                                      'STACKS' => 'cflinuxfs2')
  end

  it 'setups the deployment environment' do
    expect(@output).to include 'DEPLOYMENT NAME: test'
  end

  it 'targets a stack and deployment name' do
    expect(@output).to match /Using the stack 'cflinuxfs2' against the host 'test.cf-app.com'/
  end
end
