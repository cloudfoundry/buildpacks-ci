require 'tempfile'

require_relative '../../../tasks/finalize-security-notice-stories/finalize-security-notice-stories.rb'

describe FinalizeSecurityNoticeStories do
  let(:tracker_client) {double "tracker_client"}
  let(:new_stack_version) { 999.999 }
  let(:affected_stories) { [
    { "id"=>"487", "kind"=>"story", "label"=>"affected", "current_state"=>"started" },
    { "id"=>"987", "kind"=>"story", "label"=>"affected", "current_state"=>"started" },
  ] }

  subject { FinalizeSecurityNoticeStories.new(tracker_client, new_stack_version) }

  before(:each) do
    allow(tracker_client).to receive(:search_with_filters).with(anything).and_return(affected_stories)
    allow(tracker_client).to receive(:overwrite_label_on_story).with(affected_stories.first, 'fixed-999.999')
    allow(tracker_client).to receive(:overwrite_label_on_story).with(affected_stories.last, 'fixed-999.999')
    allow(tracker_client).to receive(:change_story_state).with('487', 'finished')
    allow(tracker_client).to receive(:change_story_state).with('987', 'finished')
  end

  it "finishes any stories tagged 'affected-<version of rootfs>' in the 'started' state and tags them with 'fixed-<version of latest rootfs>" do
    expect(tracker_client).to receive(:search_with_filters).with(label: "affected", state: "started")
    expect(tracker_client).to receive(:overwrite_label_on_story).with(story: affected_stories.first, existing_label_regex: /affected/, new_label: "fixed-999.999")
    expect(tracker_client).to receive(:overwrite_label_on_story).with(story: affected_stories.last, existing_label_regex: /affected/, new_label: "fixed-999.999")
    expect(tracker_client).to receive(:change_story_state).with(story_id: "487", current_state: "delivered")
    expect(tracker_client).to receive(:change_story_state).with(story_id: "987", current_state: "delivered")

    subject.run
  end
end
