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
    version = run("cat /tmp/build/*/version/number").strip
    this_key = 'rootfs/cflinuxfs2-' + version + '.tar.gz'
    blobs_yaml = YAML.load(output)
    shasum = "005ed7ef85a025b1280cd6133ac4fd9f6f97879b"
    expect(blobs_yaml[this_key]['sha']).to be == shasum
    expect(blobs_yaml[this_key]['size']).to be == 140
  end

  context 'with two individual git commits' do
    it 'has one that contains the blobs.yml' do
      output = run('cd /tmp/build/*/stacks-release && git show --pretty="format:" --name-only HEAD~1').strip
      expect(output).to include "config/blobs.yml"
    end

    it 'has one that contains the final release' do
      output = run('cd /tmp/build/*/stacks-release && git show --pretty="format:" --name-only HEAD').strip

      expect(output).to include "releases/stack/stack-1.22.0-rc.2.yml"
      expect(output).to include "releases/stack/index.yml"
    end
  end
end

