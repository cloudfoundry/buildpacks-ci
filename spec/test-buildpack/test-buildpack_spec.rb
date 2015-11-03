require 'spec_helper.rb'

describe 'test-buildpack task' do
  before(:context) do
    puts "Test test-buildpack task..."
    @output = fly("execute -c tasks/test-buildpack.yml " \
                  "-i buildpacks-ci=. -i buildpack=./spec/test-buildpack " \
                  "-i deployments-buildpacks=./spec/test-buildpack " \
                  "-i cf-environments=./spec/test-buildpack", {
                    "DEPLOYMENT_NAME" => "test",
                    "STACKS" => "cflinuxfs2"
                  })
    @id = @output.split("\n").first.split(' ').last
    puts "test-buildpack task id=#{@id}"
  end

  def run(cmd)
    fly("i -b #{@id} -n one-off bash -c '#{cmd}'")
  end


  it 'setups the deployment environment' do
    expect(@output).to include 'DEPLOYMENT NAME: test'
  end

  it 'targets a stack and deployment name' do
    expect(@output).to match /Using the stack 'cflinuxfs2' against the host 'test.cf-app.com'/
  end

end

