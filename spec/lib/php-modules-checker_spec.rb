# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/php-modules-checker'

describe PHPModulesChecker do
  subject { described_class }
  let(:tracker_client) { double(:tracker_client) }

  before do
    allow(TrackerClient).to receive(:new).and_return(tracker_client)
  end

  describe '#create_tracker_story' do
    it 'tries to create a Check PHP Modules story via tracker client' do
      title = 'Check and/or Update PHP Modules'
      description = <<-DESCRIPTION
Check that the PHP Module versions used in building PHP 5 and PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP5 and PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
      DESCRIPTION
      tasks = ['Check PHP 5 Modules', 'Update PHP 5 Modules', 'Check PHP 7 Modules', 'Update PHP 7 Modules']
      points = 1
      expect(tracker_client).to receive(:post_to_tracker).with(title, description, tasks, points)
      subject.create_tracker_story
    end
  end
end
