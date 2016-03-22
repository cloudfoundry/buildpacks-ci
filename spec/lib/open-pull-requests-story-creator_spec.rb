# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/open-pull-requests-story-creator'

describe OpenPullRequestsStoryCreator do
  let(:pull_requests) { [] }

  subject { described_class }

  before do
    allow(Octokit).to receive(:auto_paginate=)
    allow(Octokit).to receive(:configure)
    allow(Octokit).to receive(:pull_requests).and_return(pull_requests)
  end

  describe '#run!' do
    it 'posts to tracker with a specific story title' do
      open_prs_story_title = 'Review Open Pull Requests'
      expect(described_class).to receive(:create_tracker_story).with(open_prs_story_title, anything, anything)
      subject.run!
    end

    it 'posts to tracker with a specific story description' do
      open_prs_story_description = 'Provide feedback for open pull requests in repos that the buildpacks team owns.'
      expect(described_class).to receive(:create_tracker_story).with(anything, open_prs_story_description, anything)
      subject.run!
    end

    context 'there are open pull requests in buildpacks team repos' do
      let(:go_buildpack_pr)          { double(:go_buildpack_pr) }
      let(:go_buildpack_pr_title)    { 'Add new godep' }
      let(:go_buildpack_pr_html_url) { 'https://github.com/cloudfoundry/go-buildpack/pulls/2' }
      let(:lifecycle_pr)             { double(:lifecycle_pr) }
      let(:lifecycle_pr_title)       { 'Make .profile change' }
      let(:lifecycle_pr_html_url)    { 'https://github.com/cloudfoundry-incubator/buildpack_app_lifecycle/pulls/10' }

      before do
        allow(go_buildpack_pr).to receive(:title).and_return(go_buildpack_pr_title)
        allow(go_buildpack_pr).to receive(:html_url).and_return(go_buildpack_pr_html_url)
        allow(lifecycle_pr).to receive(:title).and_return(lifecycle_pr_title)
        allow(lifecycle_pr).to receive(:html_url).and_return(lifecycle_pr_html_url)
      end

      it 'posts to tracker with tasks that represent open PRs' do
        task1 = 'cloudfoundry/go-buildpack: Add new godep - https://github.com/cloudfoundry/go-buildpack/pulls/2'
        task2 = 'cloudfoundry-incubator/buildpack_app_lifecycle: Make .profile change - https://github.com/cloudfoundry-incubator/buildpack_app_lifecycle/pulls/10'
        open_prs_story_tasks = [task1, task2]

        expect(Octokit).to receive(:pull_requests).with('cloudfoundry/go-buildpack', state: 'open').and_return([go_buildpack_pr])
        expect(Octokit).to receive(:pull_requests).with('cloudfoundry-incubator/buildpack_app_lifecycle', state: 'open').and_return([lifecycle_pr])
        expect(described_class).to receive(:create_tracker_story).with(anything, anything, open_prs_story_tasks)
        subject.run!
      end
    end
  end
end
