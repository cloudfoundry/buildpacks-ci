# encoding: utf-8

require 'tmpdir'
require 'fileutils'
require_relative '../../../tasks/buildpack-to-master/buildpack-to-master.rb'

describe BuildpackToMaster do
  let(:git_token)                  { 'sometoken' }
  let(:git_repo)                  { 'somerepo' }
  let(:github_status_context)     { 'somecontext' }
  let(:github_status_description) { 'somedescription' }
  let(:pipelineuri)               { 'someuri' }
  let(:current_sha)               { '9999999999' }
  let(:previous_sha)               { '888888888' }

  subject { described_class.new(git_token, git_repo, github_status_context, github_status_description, pipelineuri) }


  before(:each) do
    allow(GitClient).to receive(:get_commit_sha).with('repo', 0).and_return(current_sha)
    allow(GitClient).to receive(:get_commit_sha).with('repo', 1).and_return(previous_sha)
    allow(Octokit).to receive(:list_statuses).with(git_repo, previous_sha).and_return(statuses)
    allow(GitClient).to receive(:last_commit_files).with('repo').and_return(files_changed)
    allow(subject).to receive(:puts)
  end

  context 'the previous commit does not have lts and edge statuses' do
    let(:statuses) { [{:context=>"buildpacks-ci/lts-develop"}, {:context=>"buildpacks-ci/blahhhh-develop"}] }
    let(:files_changed) { "CHANGELOG\nVERSION" }


    it 'does not add the buildpacks-ci/ready-to-merge tag' do
      expect(Octokit).not_to receive(:create_status)
      expect(Octokit).not_to receive(:update_branch)

      expect {
        subject.run
      }.to raise_error "Unsafe file changes"
    end
  end

  context 'the current commit has more file changes than it should' do
    let(:statuses) { [{:context=>"buildpacks-ci/lts-develop"}, {:context=>"buildpacks-ci/edge-develop"}] }
    let(:files_changed) { "CHANGELOG\nVERSION\nOTHERFILE" }

    it 'does not add the buildpacks-ci/ready-to-merge tag' do
      expect(Octokit).not_to receive(:create_status)
      expect(Octokit).not_to receive(:update_branch)

      expect {
        subject.run
      }.to raise_error "Unsafe file changes"
    end
  end

  context 'the current commit has no files changed' do
    let(:statuses) { [{:context=>"buildpacks-ci/lts-develop"}, {:context=>"buildpacks-ci/edge-develop"}] }
    let(:files_changed) { "" }

    it 'does not add the buildpacks-ci/ready-to-merge tag' do
      expect(Octokit).not_to receive(:create_status)
      expect(Octokit).not_to receive(:update_branch)

      expect {
        subject.run
      }.to raise_error "Unsafe file changes"
    end
  end

  context 'the previous commit has the correct statuses and the current commit only change CHANGELOG and VERSION' do
    let(:statuses) { [{:context=>"buildpacks-ci/lts-develop"}, {:context=>"buildpacks-ci/edge-develop"}] }
    let(:files_changed) { "CHANGELOG\nVERSION" }

    it 'adds the buildpacks-ci/ready-to-merge tag' do
      expect(Octokit).to receive(:create_status).with(git_repo,
                                                      current_sha,
                                                      "success",
                                                      context: github_status_context,
                                                      description: github_status_description,
                                                      target_url: pipelineuri)
      expect(Octokit).to receive(:update_branch)

      subject.run
    end
  end

  context 'the previous commit is for hwc-buildpack and only has passed edge-develop and the current commit only change CHANGELOG and VERSION' do
    let(:statuses) { [{:context=>"buildpacks-ci/edge-develop"}] }
    let(:git_repo) { 'somewhere/hwc-buildpack' }
    let(:files_changed) { "CHANGELOG\nVERSION" }

    it 'adds the buildpacks-ci/ready-to-merge tag' do
      expect(Octokit).to receive(:create_status).with(git_repo,
                                                      current_sha,
                                                      "success",
                                                      context: github_status_context,
                                                      description: github_status_description,
                                                      target_url: pipelineuri)
      expect(Octokit).to receive(:update_branch)

      subject.run
    end
  end
end
