# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/tracker-client'

describe TrackerClient do
  let(:api_key) { 'totes_a_real_api_key' }
  let(:project_id) { 'Trackergeddon' }
  let(:tracker_uri) { 'https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories' }
  let(:requester_id) { 1_234_567 }

  subject { described_class.new(api_key, project_id, requester_id) }

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

  describe '#search_by_name' do
    context 'the request is successful' do
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
          response = subject.search_by_name name: 'godep v74'
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end
    end
  end

  describe '#search_with_filters' do
    context 'the request is successful' do
      before do
        stub_request(:get, tracker_search_uri)
          .to_return(status: 200, body: response_body.to_json, headers: {})
      end

      context 'searching with one filter' do
        let(:tracker_search_uri) { "#{tracker_uri}?filter=label:some-label" }
        let(:response_body) { [
          { "id"=>"123", "kind"=>"story", "current_state"=>"accepted", "label"=>"some-label" },
          { "id"=>"987", "kind"=>"story", "current_state"=>"unscheduled", "label"=>"some-label" }
        ] }

        it 'returns matching stories' do
          response = subject.search_with_filters label: 'some-label'
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end

      context 'searching with one filter with multiple values' do
        let(:tracker_search_uri) { "#{tracker_uri}?filter=label:some-label AND label:a-second-label" }
        let(:response_body) { [
          { "id"=>"123", "kind"=>"story", "current_state"=>"accepted", "labels"=>[ "some-label" , "a-second-label" ] },
          { "id"=>"987", "kind"=>"story", "current_state"=>"unscheduled", "labels"=>[ "some-label" , "a-second-label" ] }
        ] }

        it 'returns matching stories' do
          response = subject.search_with_filters label: [ 'some-label', 'a-second-label' ]
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end

      context 'searching with multiple filters' do
        let(:tracker_search_uri) { "#{tracker_uri}?filter=label:some-label AND label:a-second-label AND state:started" }
        let(:response_body) { [
          { "id"=>"123", "kind"=>"story", "current_state"=>"started", "labels"=>[ "some-label" , "a-second-label" ] }
        ] }

        it 'returns matching stories' do
          response = subject.search_with_filters label: [ 'some-label', 'a-second-label' ], state: 'started'
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end
    end
  end

  describe '#search_by_label' do
    context 'the request is successful' do
      before do
        stub_request(:get, tracker_search_uri)
          .to_return(status: 200, body: response_body.to_json, headers: {})
      end

      context 'searching for `some-label`' do
        let(:tracker_search_uri) { "#{tracker_uri}?filter=label:some-label" }
        let(:response_body) { [
          { "id"=>"123", "kind"=>"story", "current_state"=>"accepted", "label"=>"some-label" },
          { "id"=>"987", "kind"=>"story", "current_state"=>"unscheduled", "label"=>"some-label" }
        ] }

        it 'returns matching stories' do
          response = subject.search_by_label label: 'some-label'
          expect(WebMock).to have_requested(:get, tracker_search_uri)
          expect(response).to eq response_body
        end
      end
    end
  end

  describe '#find_unaccepted_story_ids' do
    let(:text_to_search_for) { 'text of interest' }

    before do
      allow(subject).to receive(:search_by_name).with(name: text_to_search_for).and_return(stories)
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
        before do
          stub_request(:post, tracker_uri)
            .with(body: '{"name":"OH NOOOO","description":"OH NOOOOOOOOOOOOOOOOOO","requested_by_id":1234567,"tasks":[{"description":"Taskmaster"},{"description":"Marvel"}],"labels":[{"name":"code-complete"}],"estimate":1}')
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

          subject.post_to_tracker(name: name, description: description, tasks: tasks, point_value: point_value, labels: labels)

          expect(WebMock).to have_requested(:post, tracker_uri)
            .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
        end

        it 'has the api key that was passed to it in the header' do
          subject.post_to_tracker(name: name, description: description, tasks: tasks, point_value: point_value, labels: labels)

          expected_headers = {
            'Content-Type' => 'application/json',
            'X-TrackerToken' => 'totes_a_real_api_key'
          }

          expect(WebMock).to have_requested(:post, tracker_uri)
            .with(headers: expected_headers)
        end
      end

      context 'the story name is empty' do
        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: '', description: 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story name is nil' do
        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: nil, description: 'WHAT HAVE YOU DOONNNNNNNNNNE', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is empty' do
        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: 'a', description: '', tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end

      context 'the story description is nil' do
        it 'raises an exception without posting to Tracker' do
          expect { subject.post_to_tracker name: 'a', description: nil, tasks: tasks, point_value: point_value, labels: labels }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, tracker_uri)
        end
      end
    end

    describe 'API error checking' do
      before do
        stub_request(:post, tracker_uri)
          .to_return(status: [404, 'page not found'], body: '', headers: {})
      end

      context 'API call is not successful' do
        it 'raises an HTTP error' do
          expect { subject.post_to_tracker name: 'YOU FOOL', description: 'WHAT HAVE YOU DOONNNNNNNNNNE', point_value: []}
            .to raise_error(RuntimeError)
        end
      end
    end
  end

  describe '#add_blocker_to_story' do
    let(:story_id) { 98123 }
    let(:blocker) { double('blocker', id: 234, name: 'something important', current_state: 'accepted') }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}/blockers" }

    before do
      stub_request(:post, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.add_blocker_to_story(story_id: story_id, blocker: blocker)
      expect(WebMock).to have_requested(:post, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.add_blocker_to_story(story_id: story_id, blocker: blocker)

      expected_payload = {description: "#234 - something important", person_id: 1234567, resolved: true}.to_json
      expect(WebMock).to have_requested(:post, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.add_blocker_to_story(story_id: story_id, blocker: blocker)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:post, tracker_uri)
        .with(headers: expected_headers)
    end

    context 'current_state is not accepted' do
      let(:blocker) { double('blocker', id: 234, name: 'something important', current_state: 'started') }
      it 'sets resolved to false' do
        subject.add_blocker_to_story(story_id: story_id, blocker: blocker)

        expected_payload = {description: "#234 - something important", person_id: 1234567, resolved: false}.to_json
        expect(WebMock).to have_requested(:post, tracker_uri)
          .with(body: expected_payload)
      end
    end
  end

  describe '#add_label_to_story' do
    let(:story_id) { 99999 }
    let(:story) {
      {
        "kind"=>"story",
        "id"=>story_id,
        "labels"=>[
          {"id"=>31337, "project_id"=>42, "kind"=>"label", "name"=>"existing-label-1", "created_at"=>"2017-07-19T15:15:15Z", "updated_at"=>"2017-07-19T15:15:15Z"},
          {"id"=>31338, "project_id"=>42, "kind"=>"label", "name"=>"existing-label-2", "created_at"=>"2017-07-19T15:15:15Z", "updated_at"=>"2017-07-19T15:15:15Z"}
        ]
      }
    }
    let(:new_label) { "its-a-new-label" }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}" }

    before do
      stub_request(:put, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.add_label_to_story(story: story, label: new_label)
      expect(WebMock).to have_requested(:put, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.add_label_to_story(story: story, label: new_label)

      expected_payload = { labels: [ { name: "its-a-new-label" },
                                     { id: 31337, project_id: 42, name: "existing-label-1" },
                                     { id: 31338, project_id: 42, name: "existing-label-2" } ] }.to_json
      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.add_label_to_story(story: story, label: new_label)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(headers: expected_headers)
    end
  end

  describe '#overwrite_label_on_story' do
    let(:story_id) { 99999 }
    let(:story) {
      {
        "kind"=>"story",
        "id"=>story_id,
        "labels"=>[
          {"id"=>31337, "project_id"=>42, "kind"=>"label", "name"=>"existing-label-1", "created_at"=>"2017-07-19T15:15:15Z", "updated_at"=>"2017-07-19T15:15:15Z"},
          {"id"=>31338, "project_id"=>42, "kind"=>"label", "name"=>"existing-label-2", "created_at"=>"2017-07-19T15:15:15Z", "updated_at"=>"2017-07-19T15:15:15Z"}
        ]
      }
    }
    let(:new_label) { "this-is-a-new-label" }
    let(:existing_label_regex) { /existing-label-*/ }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}" }

    before do
      stub_request(:put, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.overwrite_label_on_story(story: story, existing_label_regex: existing_label_regex, new_label: new_label)
      expect(WebMock).to have_requested(:put, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.overwrite_label_on_story(story: story, existing_label_regex: existing_label_regex, new_label: new_label)

      expected_payload = { labels: [ { name: "this-is-a-new-label" } ] }.to_json
      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.overwrite_label_on_story(story: story, existing_label_regex: existing_label_regex, new_label: new_label)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(headers: expected_headers)
    end
  end

  describe '#add_comment_to_story' do
    let(:story_id) { 89989 }
    let(:comment) { "this is a random comment!!!!!!!!!!!!!" }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}/comments" }

    before do
      stub_request(:post, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.add_comment_to_story(story_id: story_id, comment: comment)
      expect(WebMock).to have_requested(:post, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.add_comment_to_story(story_id: story_id, comment: comment)

      expected_payload = { text: "this is a random comment!!!!!!!!!!!!!" }.to_json
      expect(WebMock).to have_requested(:post, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.add_comment_to_story(story_id: story_id, comment: comment)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:post, tracker_uri)
        .with(headers: expected_headers)
    end
  end

  describe '#point_story' do
    let(:story_id) { 8888 }
    let(:estimate) { 3 }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}" }

    before do
      stub_request(:put, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.point_story(story_id: story_id, estimate: estimate)
      expect(WebMock).to have_requested(:put, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.point_story(story_id: story_id, estimate: estimate)

      expected_payload = { estimate: 3 }.to_json
      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.point_story(story_id: story_id, estimate: estimate)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(headers: expected_headers)
    end
  end

  describe '#changes_story_state' do
    let(:story_id) { 762172 }
    let(:current_state) { "started" }
    let(:tracker_uri) { "https://www.pivotaltracker.com:443/services/v5/projects/Trackergeddon/stories/#{story_id}" }

    before do
      stub_request(:put, tracker_uri)
        .to_return(status: 200, body: '', headers: {})
    end

    it 'receives the 200 status code' do
      response = subject.change_story_state(story_id: story_id, current_state: current_state)
      expect(WebMock).to have_requested(:put, tracker_uri)
      expect(response.code).to eq '200'
    end

    it 'has the correct payload' do
      subject.change_story_state(story_id: story_id, current_state: current_state)

      expected_payload = { current_state: "started" }.to_json
      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(body: expected_payload, headers: { 'Content-Type' => 'application/json' })
    end

    it 'has the api key that was passed to it in the header' do
      subject.change_story_state(story_id: story_id, current_state: current_state)

      expected_headers = {
        'Content-Type' => 'application/json',
        'X-TrackerToken' => 'totes_a_real_api_key'
      }

      expect(WebMock).to have_requested(:put, tracker_uri)
        .with(headers: expected_headers)
    end
  end
end
