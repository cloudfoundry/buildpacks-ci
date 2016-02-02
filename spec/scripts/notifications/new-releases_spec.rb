# encoding: utf-8
require 'spec_helper'
require 'open3'

describe 'New Releases script' do
  before { @new_releases_dir = Dir.mktmpdir }
  after { FileUtils.remove_entry @new_releases_dir }

  subject { "./scripts/notifications/new-releases #{@new_releases_dir}" }

  context 'there are new releases' do
    before { `cp ./spec/fixtures/new-release-notifications/ruby_with_missing_releases.yaml #{@new_releases_dir}/ruby.yaml` }

    it 'outputs a new dependency updates message and the new releases' do
      stdout, stderr, status = Open3.capture3(subject)
      expect(stdout).to match(/There are \*[\d]+\* new updates to the \*ruby\* dependency/)
      expect(stdout).to include('*v2_3_0')
      expect(stdout).to include('*v2_2_4')
    end
  end

  context 'there are no new releases' do
    before { `#{subject}` }

    it 'outputs that there are no new updates to dependencies' do
      stdout, stderr, status = Open3.capture3(subject)
      expect(stdout).to eq('')
      expect(stderr).to include('There are no new updates to the *ruby* dependency')
    end
  end
end
