require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'create bosh stacks release task' do
  before(:context) do
    execute("-c tasks/create-bosh-stacks-release.yml " +
            "-i buildpacks-ci=. " +
            "-i stack-s3=./spec/create-bosh-stacks-release/stack-s3 " +
            "-i version=./spec/create-bosh-stacks-release/version " +
            "-i stacks-release=./spec/create-bosh-stacks-release/stacks-release ",
            )
  end

  it 'should modify config/blobs.yml correctly' do
    output = run("cat /tmp/build/*/stacks-release/config/blobs.yml").to_s
    version = run("cat /tmp/build/*/version/number").to_s.chomp('')
    # STDERR.puts "version:\n"
    # STDERR.puts version
    # first_parts = 'rootfs/cflinuxfs2' + version
    # STDERR.puts first_parts
    # STDERR.puts first_parts, ".tar.gz"
    # this_key = 'rootfs/cflinuxfs2' + version + '.tar.gz'
    # STDERR.puts "file:\n"
    # STDERR.puts this_key
    blobs_yaml = YAML.load(output)
    # STDERR.puts blobs_yaml.keys.first
    # STDERR.puts "here is a longer string that should be alright"
    # STDOUT.puts "here is a longer string" << version << "this"
    shasum = "005ed7ef85a025b1280cd6133ac4fd9f6f97879b"
    first_entry = blobs_yaml.keys.first
    expect(blobs_yaml[first_entry]['sha']).to be == shasum
    expect(blobs_yaml[first_entry]['size']).to be == 140
  end
end

