# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require 'tmpdir'
require 'with_env'
require_relative '../scripts/concourse2tracker'

describe 'When a concourse job finishes' do
  include WithEnv

  around do |example|
    with_env('BUILD_ID' => 'some_build_id') do
      example.run
    end
  end

  context 'when the resource is a git resource' do
    context 'and has commits with tracker story IDs' do
      it 'adds a comment to that tracker story' do
        git_dir = Dir.mktmpdir
        system(<<-EOL)
          cd #{git_dir}
          git init
          touch README
          git add -A
          git commit -m 'some commit [#1234567]'
        EOL

        client = Concourse2Tracker.new(
          git_path:   git_dir,
          project_id: 9.87654e05,
          api_token:  '3695'
        )

        expect(client.story_id).to eq '1234567'

        stub = stub_request(:post, 'https://www.pivotaltracker.com/services/v5/projects/987654/stories/1234567/comments')
               .with(body: { text: 'Concourse pipeline passed: https://concourse.buildpacks-gcp.ci.cf-app.com/builds/some_build_id' })
               .with(headers: { 'X-TrackerToken' => '3695', 'Content-Type' => 'application/json' })

        client.process!

        expect(stub).to have_been_requested
      end
    end

    context 'and has no commits with tracker story IDs' do
      it 'does nothing' do
        git_dir = Dir.mktmpdir
        system(<<-EOL)
          cd #{git_dir}
          git init
          touch README
          git add -A
          git commit -m 'some commit'
        EOL

        client = Concourse2Tracker.new(
          git_path:   git_dir,
          project_id: 'project_id',
          api_token:  '3695'
        )

        expect(client.story_id).to eq nil

        stub = stub_request(:post, 'https://www.pivotaltracker.com/services/v5/projects/project_id/stories/1234567/comments')
        client.process!

        expect(stub).to_not have_been_requested
      end
    end
  end

  context 'when the resource is not a git resource' do
    it 'does nothing' do
      client = Concourse2Tracker.new(
        git_path:   Dir.mktmpdir,
        project_id: 'project_id',
        api_token:  '3695'
      )

      expect(client.story_id).to eq nil

      stub = stub_request(:post, 'https://www.pivotaltracker.com/services/v5/projects/project_id/stories/1234567/comments')
      client.process!

      expect(stub).to_not have_been_requested
    end
  end
end
