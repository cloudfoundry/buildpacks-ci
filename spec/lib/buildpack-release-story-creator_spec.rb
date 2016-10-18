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
  end

  it 'finds the previous release' do
    allow(buildpack_project).to receive(:stories).and_return([double(id: 1)],
                                                             [double(id:111111111, name:'this does not matter for this test')])
    allow(buildpack_project).to receive(:create_story).and_return(true)

    subject.run!

    expect(buildpack_project).to have_received(:stories)
                                     .with({filter: "label:release AND label:#{buildpack_name}"})
  end

  context 'previous release stories exist' do
    it 'finds all the accepted buildpack_name-tagged stories since the last release' do
      allow(buildpack_project).to receive(:stories).and_return([double(id: 1)],
                                                               [double(id:111111111, name:'this does not matter for this test')])
      allow(buildpack_project).to receive(:create_story).and_return(true)

      subject.run!

      expect(buildpack_project).to have_received(:stories)
                                       .with({with_label: 'elixir', after_story_id: 1})
    end
  end

  context 'no previous release stories exist' do
    it 'finds all the accepted buildpack_name-tagged stories' do
      allow(buildpack_project).to receive(:stories).and_return([],
                                                               [double(id:111111111, name:'noname'), double(id:222222222, name:'noname')])
      allow(buildpack_project).to receive(:create_story).and_return(true)

      subject.run!

      expect(buildpack_project).to have_received(:stories)
                                       .with({with_label: 'elixir'})
    end
  end

  it 'posts a new buildpack release story to Tracker' do
    allow(buildpack_project).to receive(:stories).and_return([double(id: 1)],
                                                             [double(id:111111111, name:'Elixir should be faster'),
                                                              double(id:222222222, name:'Buildpack should tweet on stage')])

    expect(buildpack_project).to receive(:create_story).
        with(name: '**Release:** elixir-buildpack 2.10.4',
             description: <<~DESCRIPTION,
                          Stories:

                          #111111111 - Elixir should be faster
                          #222222222 - Buildpack should tweet on stage

                          Refer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).
                          DESCRIPTION
             estimate: 1,
             labels: %w(elixir release),
             requested_by_id: 555555
        )

    subject.run!
  end
end
