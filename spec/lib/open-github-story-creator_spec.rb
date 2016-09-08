# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/open-github-story-creator'

describe OpenGithubStoryCreator do
  let(:pull_requests) { [] }
  let(:issues) { [] }

  subject { described_class }

  before do
    allow(Octokit).to receive(:auto_paginate=)
    allow(Octokit).to receive(:configure)
    allow(Octokit).to receive(:pull_requests).and_return(pull_requests)
    allow(Octokit).to receive(:list_issues).and_return(issues)
  end

  describe '#create_pull_requests_story' do
    it 'posts to tracker with a specific story title' do
      open_prs_story_title = 'Review Open Pull Requests'
      expect(described_class).to receive(:create_tracker_story).with(open_prs_story_title, anything, anything, anything, anything)
      subject.create_pull_requests_story
    end

    it 'posts to tracker with a specific story description' do
      open_prs_story_description = 'Provide feedback for open pull requests in repos that the buildpacks team owns.'
      expect(described_class).to receive(:create_tracker_story).with(anything, open_prs_story_description, anything, anything, anything)
      subject.create_pull_requests_story
    end

    it 'posts to tracker with the maintenance label' do
      expect(described_class).to receive(:create_tracker_story).with(anything, anything, anything, anything, ['maintenance'])
      subject.create_pull_requests_story
    end

    it 'posts to tracker with a point value of 1' do
      expect(described_class).to receive(:create_tracker_story).with(anything, anything, anything, 1, anything)
      subject.create_pull_requests_story
    end

    context 'there are open pull requests in buildpacks team repos' do
      let(:go_buildpack_pr)          { double(:go_buildpack_pr) }
      let(:go_buildpack_pr_title)    { 'Add new godep' }
      let(:go_buildpack_pr_html_url) { 'https://github.com/cloudfoundry/go-buildpack/pulls/2' }

      before do
        allow(go_buildpack_pr).to receive(:title).and_return(go_buildpack_pr_title)
        allow(go_buildpack_pr).to receive(:html_url).and_return(go_buildpack_pr_html_url)
      end

      it 'posts to tracker with tasks that represent open PRs' do
        task1 = 'cloudfoundry/go-buildpack: Add new godep - https://github.com/cloudfoundry/go-buildpack/pulls/2'
        open_prs_story_tasks = [task1]

        expect(Octokit).to receive(:pull_requests).with('cloudfoundry/go-buildpack', state: 'open').and_return([go_buildpack_pr])
        expect(described_class).to receive(:create_tracker_story).with(anything, anything, open_prs_story_tasks, anything, anything)
        subject.create_pull_requests_story
      end
    end
  end

  describe '#create_issues_story' do
    it 'posts to tracker with a specific story title' do
      open_prs_story_title = 'Review Open Issues'
      expect(described_class).to receive(:create_tracker_story).with(open_prs_story_title, anything, anything, anything, anything)
      subject.create_issues_story
    end

    it 'posts to tracker with a specific story description' do
      open_prs_story_description = 'Provide feedback for open issues in repos that the buildpacks team owns.'
      expect(described_class).to receive(:create_tracker_story).with(anything, open_prs_story_description, anything, anything, anything)
      subject.create_issues_story
    end

    it 'posts to tracker with the maintenance label' do
      expect(described_class).to receive(:create_tracker_story).with(anything, anything, anything, anything, ['maintenance'])
      subject.create_issues_story
    end

    it 'posts to tracker with a point value of 1' do
      expect(described_class).to receive(:create_tracker_story).with(anything, anything, anything, 1, anything)
      subject.create_issues_story
    end

    context 'there are open issues in buildpacks team repos' do
      let(:go_buildpack_issue)          { double(:go_buildpack_issue) }
      let(:go_buildpack_issue_title)    { 'where my new godep' }
      let(:go_buildpack_issue_html_url) { 'https://github.com/cloudfoundry/go-buildpack/issues/2' }
      let(:go_buildpack_pr)             { double(:go_buildpack_pr) }
      let(:go_buildpack_pr_title)       { 'Make .profile change' }
      let(:go_buildpack_pr_html_url)    { 'https://github.com/cloudfoundry/go-buildpack/pulls/12' }

      before do
        allow(go_buildpack_issue).to receive(:title).and_return(go_buildpack_issue_title)
        allow(go_buildpack_issue).to receive(:html_url).and_return(go_buildpack_issue_html_url)
        allow(go_buildpack_issue).to receive(:pull_request).and_return(nil)
        allow(go_buildpack_pr).to receive(:title).and_return(go_buildpack_pr_title)
        allow(go_buildpack_pr).to receive(:html_url).and_return(go_buildpack_pr_html_url)
        allow(go_buildpack_pr).to receive(:pull_request).and_return(double(:pull_request_content))
      end

      it 'posts to tracker with tasks that represent open issues' do
        task1 = 'cloudfoundry/go-buildpack: where my new godep - https://github.com/cloudfoundry/go-buildpack/issues/2'
        open_issues_story_tasks = [task1]

        expect(Octokit).to receive(:list_issues).with('cloudfoundry/go-buildpack', state: 'open').and_return([go_buildpack_issue])
        expect(described_class).to receive(:create_tracker_story).with(anything, anything, open_issues_story_tasks, anything, anything)
        subject.create_issues_story
      end
    end
  end
end
