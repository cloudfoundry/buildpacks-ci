# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/tracker-client'

describe TrackerClient do
  let(:api_key) { 'totes_a_real_api_key' }
  let(:project_id) { 'Trackergeddon' }
  let(:tracker_uri) { 'https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories' }
  let(:requester_id) { 1_234_567 }

  describe '#initialize' do
    context 'the api key is nil' do
      subject { described_class.new(nil, project_id, requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the project id is nil' do
      subject { described_class.new(api_key, nil, requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the api key is empty' do
      subject { described_class.new('', project_id, requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the project id is empty' do
      subject { described_class.new(api_key, '', requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the api key is not a string' do
      subject { described_class.new(12_345, project_id, requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the project id is not a string' do
      subject { described_class.new(api_key, 12_345, requester_id) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the requester id is nil' do
      subject { described_class.new(api_key, project_id, nil) }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the requester id is not a number' do
      subject { described_class.new(api_key, project_id, '') }

      it 'raises an exception without posting to Tracker' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#search' do
    context 'the request is successful' do
      subject { described_class.new(api_key, project_id, requester_id) }

      before do
        stub_request(:get, tracker_search_uri)
          .to_return(status: 200, body: response_body.to_json, headers: {})
      end

      context 'searching for `godep v74`' do
        let(:tracker_search_uri) { "#{tracker_uri}?filter=name:godep+v74" }
        let(:response_body) { [
          { "id"=>"123", "kind"=>"story", "current_state"=>"accepted" },
          { "id"=>"987", "kind"=>"story", "current_state"=>"accepted" }
        ] }

        it 'returns matching stories' do
          response = subject.search name: 'godep v74'
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end
    end
  end

  describe '#find_unaccepted_story_ids' do
    subject { described_class.new(api_key, project_id, requester_id) }
    let(:text_to_search_for) { 'text of interest' }

    before do
      allow(subject).to receive(:search).and_return(stories)
    end

    context 'with accepted and unaccepted stories that match query text' do
      let(:stories) {
        [
          { 'id' => 111_111_111, 'current_state' => 'accepted' },
          { 'id' => 999_999_999, 'current_state' => 'not even vaguely accepted, lol' },
        ]
      }

      it 'should return only story ids of unaccepted stories' do
        story_ids = subject.find_unaccepted_story_ids(text_to_search_for)
        expect(story_ids).to eq [999_999_999]
      end
    end

    context 'with no stories that match query text' do
      let(:stories) { [] }

      it 'should return no story ids' do
        story_ids = subject.find_unaccepted_story_ids(text_to_search_for)
        expect(story_ids).to be_empty
      end
    end
  end

  describe '#post_to_tracker' do
    describe 'input checking' do
      let(:name)        { 'OH NOOOO' }
      let(:description) { 'OH NOOOOOOOOOOOOOOOOOO' }
      let(:tasks)       { %w(Taskmaster Marvel) }
      let(:point_value) { 1 }
      let(:labels)        { %w(code-complete) }

      context 'the POST request is successful' do
        subject { described_class.new(api_key, project_id, requester_id) }

        before do
          stub_request(:post, tracker_uri)
            .with(body: '{"name":"OH NOOOO","description":"OH NOOOOOOOOOOOOOOOOOO","requested_by_id":1234567,"tasks":[{"description":"Taskmaster"},{"description":"Marvel"}],"labels":[{"name":"code-complete"}],"estimate":1}',
                  headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'Host' => 'www.pivotaltracker.com', 'User-Agent' => 'Ruby', 'X-Trackertoken' => 'totes_a_real_api_key' })
            .to_return(status: 200, body: '', headers: {})
        end

        it 'receives the 200 status code' do
          response = subject.post_to_tracker(name: name, description: description, tasks: tasks, point_value: point_value, labels: labels)
          expect(WebMock).to have_requested(:post, tracker_uri)
          expect(response.code).to eq '200'
        end

        it 'has the correct payload' do
          expected_payload = {
            name: name,
            description: description,
            requested_by_id: requester_id,
            tasks: [{ description: 'Taskmaster' }, { description: 'Marvel' }],
            labels: [{ name: 'code-complete' }],
            estimate: 1
          }.to_json

          response = subject.post_to_tracker(name: name, description: description, tasks: tasks, point_value: point_value, labels: labels)

          expect(WebMock).to have_requested(:post, tracker_uri)
            .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
        end

        it 'has the api key that was passed to it in the header' do
          response = subject.post_to_tracker(name: name, description: description, tasks: tasks, point_value: point_value, labels: labels)

          expected_headers = {
            'Content-Type' => 'application/json',
            'X-TrackerToken' => 'totes_a_real_api_key'
          }

          expect(WebMock).to have_requested(:post, tracker_uri)
            .with(headers: expected_headers)
        end
      end

      context 'the story name is empty' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: '', description: 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story name is nil' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: nil, description: 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is empty' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: 'a', description: '', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is nil' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: 'a', description: nil, tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end
    end

    describe 'API error checking' do
      before do
        stub_request(:post, tracker_uri)
          .with(headers: {
                  'Accept' => '*/*',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Host' => 'www.pivotaltracker.com',
                  'User-Agent' => 'Ruby'
                })
          .to_return(status: [404, 'page not found'], body: '', headers: {})
      end

      context 'API call is not successful' do
        subject { described_class.new(api_key, project_id, requester_id) }
        it 'raises an HTTP error' do
          expect { subject.post_to_tracker name: 'YOU FOOL', description: 'WHAT HAVE YOU DOONNNNNNNNNNE', point_value: []}
            .to raise_error(RuntimeError)
        end
      end
    end
  end
end
