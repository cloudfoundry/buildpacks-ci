# encoding: utf-8
require 'tmpdir'
require 'tempfile'
require 'json'
require 'open3'

RSpec.configure do |config|
  config.order = :random

  $stdout.sync = true
  config.filter_run_excluding concourse_test: true

  # Run tests in living color, even on CI
  config.color = true
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :json, CustomFormatterClass

  config.before do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  config.after(:all) do
    $stdout = STDOUT
    $stderr = STDERR
  end

  def fly(arg, env = {})
    target = 'buildpacks'
    env_var = env.collect { |k, v| "#{k}=#{v}" }.join(' ')
    out, err, status = Open3.capture3("env #{env_var} fly --target #{target} #{arg} | tee /tmp/fly.log")
    raise "Failed: env #{env_var} fly --target #{target} #{arg} | tee /tmp/fly.log" if !status.success? or err =~ /error: websocket: bad handshake/
    out
  end

  def execute(cmd, env = {})
    fly("execute #{cmd}", env)
  end
end
