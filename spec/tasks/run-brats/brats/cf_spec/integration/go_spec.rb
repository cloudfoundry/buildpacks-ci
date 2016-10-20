# encoding: utf-8
describe 'go_spec test', concourse_test: true, language: 'go' do
  it 'setups the deployment environment' do
    puts 'This spec has ran'
    expect(1).to equal 1
  end
end
