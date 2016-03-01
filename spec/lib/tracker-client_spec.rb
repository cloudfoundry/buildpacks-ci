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

  describe '#post_to_tracker' do
    describe 'input checking' do
      let(:name)        { 'OH NOOOO' }
      let(:description) { 'OH NOOOOOOOOOOOOOOOOOO' }
      let(:tasks)       { %w(Taskmaster Marvel) }

      context 'the POST request is successful' do
        subject { described_class.new(api_key, project_id, requester_id) }

        before do
          stub_request(:post, tracker_uri)
            .with(body: '{"name":"OH NOOOO","description":"OH NOOOOOOOOOOOOOOOOOO","requested_by_id":1234567,"tasks":[{"description":"Taskmaster"},{"description":"Marvel"}]}',
                  headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'Host' => 'www.pivotaltracker.com', 'User-Agent' => 'Ruby', 'X-Trackertoken' => 'totes_a_real_api_key' })
            .to_return(status: 200, body: '', headers: {})
        end

        it 'receives the 200 status code' do
          response = subject.post_to_tracker name, description, tasks
          expect(WebMock).to have_requested(:post, tracker_uri)
          expect(response.code).to eq '200'
        end

        it 'has the correct payload' do
          expected_payload = {
            name: name,
            description: description,
            requested_by_id: requester_id,
            tasks: [{ description: 'Taskmaster' }, { description: 'Marvel' }]
          }.to_json

          response = subject.post_to_tracker name, description, tasks

          expect(WebMock).to have_requested(:post, tracker_uri)
            .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
        end

        it 'has the api key that was passed to it in the header' do
          response = subject.post_to_tracker name, description, tasks

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
          expect { subject.post_to_tracker '', 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story name is nil' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker nil, 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is empty' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker 'a', '', tasks }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is nil' do
        subject { described_class.new(api_key, project_id, requester_id) }

        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker 'a', nil, tasks }.to raise_error(RuntimeError)
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
          expect { subject.post_to_tracker 'YOU FOOL', 'WHAT HAVE YOU DOONNNNNNNNNNE', [] }
            .to raise_error(RuntimeError)
        end
      end
    end
  end
end
