# encoding: utf-8
require 'spec_helper.rb'

describe 'run-brats task' do
  before(:context) do
    execute('-c tasks/run-brats/task.yml ' \
            '-i buildpacks-ci=. -i brats=./spec/tasks/run-brats/brats ' \
            '-i cf-environments=./spec/tasks/run-brats', 'LANGUAGE' => 'go')
  end

  it 'setups the deployment environment' do
    expect(@output).to include 'This spec has ran'
  end
end
