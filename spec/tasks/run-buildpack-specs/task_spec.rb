# encoding: utf-8
require 'spec_helper.rb'

describe 'run-buildpack-specs task' do
  before(:context) do
    execute('-c tasks/run-buildpack-specs/task.yml ' \
            '-p ' \
            '-i buildpacks-ci=. -i buildpack=./spec/tasks/run-buildpack-specs ' \
            '-i cf-environments=./spec/tasks/run-buildpack-specs',   'DEPLOYMENT_NAME' => 'test',
                                                                      'STACKS' => 'cflinuxfs2',
                                                                      'RUBYGEM_MIRROR' => 'https://rubygems.org',
                                                                      'BOSH_LITE_DOMAIN_NAME' => 'cf-app.com'
           )
  end

  it 'targets a stack and deployment name' do
    expect(@output).to match /Using the stack 'cflinuxfs2' against the host 'test.cf-app.com'/
  end
end
