# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/buildpack-release-story-creator'

describe BuildpackReleaseStoryCreator do
  let(:buildpack_name) { 'elixir' }
  let(:previous_buildpack_version) { '2.10.3' }
  let(:tracker_project_id) { 'tracker_project_id_stub' }
  let(:tracker_requester_id) { 555555 }
  let(:tracker_api_token) { 'tracker_api_token_stub' }
  let(:tracker_client) { double(TrackerApi::Client) }
  let(:buildpack_project) { instance_double(TrackerApi::Resources::Project) }
  let(:new_story) { double('new_story', id: 987) }
  let(:release_stories) { [] }
  let(:all_stories) { [double(id:110, name:'Older Release'),
                       double(id:111, name:'Elixir should be faster'),
                       double(id:221, name:'Latest Release'),
                       double(id:222, name:'Buildpack should tweet on stage'),
                       double(id:333, name:'All buildpacks should be awesome')] }

  subject { described_class.new(buildpack_name: buildpack_name,
                                previous_buildpack_version: previous_buildpack_version,
                                tracker_project_id: tracker_project_id,
                                tracker_requester_id: tracker_requester_id,
                                tracker_api_token: tracker_api_token
                                )}

  before do
    allow(TrackerApi::Client).to receive(:new).with({token: tracker_api_token})
      .and_return(tracker_client)
    allow(tracker_client).to receive(:project).with(tracker_project_id)
      .and_return(buildpack_project)

    allow(buildpack_project).to receive(:stories).with({filter: "label:release AND label:elixir AND -state:unscheduled"}).and_return(release_stories)
    allow(buildpack_project).to receive(:stories).with({filter: "(label:elixir OR label:all) AND (accepted_after:09/24/2015 OR -state:accepted)", limit: 1000, auto_paginate: true}).and_return(all_stories)
  end

  context 'previous release stories exist' do
    let(:release_stories) { [double(id: 110), double(id: 221)] }
    it 'finds all the stories tagged buildpack_name or all that are lower in the backlog than the last release' do
      expect(buildpack_project).to receive(:create_story).
        with(hash_including(description: <<~DESCRIPTION,
          Stories:

          #222 - Buildpack should tweet on stage
          #333 - All buildpacks should be awesome

          Refer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).
          DESCRIPTION
        )).and_return(new_story)
      expect(new_story).to receive(:description=).
          with(anything())
      expect(new_story).to receive(:save)

      subject.run!
    end
  end

  context 'no previous release stories exist' do
    let(:release_stories) { [] }

    it 'finds all the stories tagged buildpack_name or all' do
      expect(buildpack_project).to receive(:create_story).
        with(hash_including(description: <<~DESCRIPTION,
          Stories:

          #110 - Older Release
          #111 - Elixir should be faster
          #221 - Latest Release
          #222 - Buildpack should tweet on stage
          #333 - All buildpacks should be awesome

          Refer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).
          DESCRIPTION
        )).and_return(new_story)
      expect(new_story).to receive(:description=).
         with(anything())
      expect(new_story).to receive(:save)

      subject.run!
    end
  end

  it 'posts a new buildpack release story to Tracker' do
    expect(buildpack_project).to receive(:create_story).
        with(name: '**Release:** elixir-buildpack 2.10.4',
             description: anything(),
             estimate: 0,
             labels: %w(elixir release),
             requested_by_id: 555555
            ).and_return(new_story)
    expect(new_story).to receive(:description=).
      with(anything())
    expect(new_story).to receive(:save)

    subject.run!
  end

  context 'previous release is 2.3.9' do
    let(:previous_buildpack_version) { '2.3.9' }

    it 'increases the patch correctly' do
      expect(buildpack_project).to receive(:create_story).
        with(hash_including(name: '**Release:** elixir-buildpack 2.3.10')).and_return(new_story)
      expect(new_story).to receive(:description=).
        with(anything())
      expect(new_story).to receive(:save)

      subject.run!
    end
  end
end
