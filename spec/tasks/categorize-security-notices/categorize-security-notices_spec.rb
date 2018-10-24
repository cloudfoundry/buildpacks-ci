require 'json'
require 'webmock/rspec'
require 'tempfile'

require_relative '../../../tasks/categorize-security-notices/categorize-security-notices'

describe CategorizeSecurityNotices do

  let(:stack_to_version) {
    {
    "cflinuxfs2" => "14.04",
    "cflinuxfs3" => "18.04"
    }
  }
  let(:tracker_client) { double "tracker_client" }
  let(:stories_file) { Tempfile.new }
  let(:stack_receipt) { Tempfile.new }

  def affected_story_content(stack)
    <<-STORY
**Product:** #{stack}
**Severity:** medium
**USN:** http://www.ubuntu.com/usn/usn-3353-1/
**14.04 Packages:**
libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.2
libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.3
**16.04 Packages:**
libkrb5-26-heimdal 1.7~git20150920+dfsg-4ubuntu1.16.04.1
**18.04 Packages:**
libkrb5-26-heimdal 1.7~git20150920+dfsg-4ubuntu1.18.04.1
STORY
  end

  def affected_story_content_only_one_stack(stack)
    <<-STORY
**Product:** #{stack}
**Severity:** medium
**USN:** http://www.ubuntu.com/usn/usn-3353-1/
**#{stack_to_version[stack]} Packages:**
libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.2
STORY
  end

  def unaffected_story_content(stack)
    <<-STORY
**Product:** #{stack}
**Severity:** medium
**USN:** http://www.ubuntu.com/usn/usn-3353-1/
**#{stack_to_version[stack]} Packages:**
nginx-extras 1.4.6-1ubuntu3.8
STORY
  end

  let(:receipt_content) { "ii  libkrb5-26-heimdal:amd64           1.6~git20131207+dfsg-1ubuntu1.4            amd64        Heimdal Kerberos - libraries\n" +
      "ii  evince   3.10.3-0ubuntu10.3\n" +
      "ii  evince-common    3.10.2-0ubuntu10.3\n" }

  context "when the stack is cflinuxfs2" do
    let(:stories_json) {
      stories = [
        {
          "id": '123',
          "description": affected_story_content('cflinuxfs2'),
          "labels": %w(cflinuxfs2 security-notice some-label)
        },
        {
          "id": '456',
          "description": unaffected_story_content('cflinuxfs2'),
          "labels": %w(cflinuxfs2 security-notice some-other-label)
        },
        {
          "id": '789',
          "description": affected_story_content_only_one_stack('cflinuxfs2'),
          "labels": %w(cflinuxfs2 security-notice some-other-label)
        }
      ]
      JSON.dump({ version: { ref: JSON.dump(stories) } })
    }

    subject { CategorizeSecurityNotices.new(tracker_client, stories_file.path, stack_receipt.path, 'cflinuxfs2') }

    before(:each) do
      allow(tracker_client).to receive(:add_label_to_story).with(anything)
      allow(tracker_client).to receive(:point_story).with(anything)
      allow(tracker_client).to receive(:change_story_state).with(anything)

      stories_file.write(stories_json)
      stories_file.close
      stack_receipt.write(receipt_content)
      stack_receipt.close
    end

    it "labels any stories unrelated to the rootfs with 'unaffected', points them with 0, and delivers them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "456",
                                                                           "description" => unaffected_story_content('cflinuxfs2'),
                                                                           "labels" => ["cflinuxfs2", "security-notice", "some-other-label"] }, label: "unaffected")
      expect(tracker_client).to receive(:point_story).with(story_id: "456", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "456", current_state: "delivered")

      subject.run
    end

    it "labels any stories related to the rootfs (regardless of package version) with 'affected', points them with 0, and starts them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "123",
                                                                           "description" => "#{affected_story_content('cflinuxfs2')}",
                                                                           "labels" => ["cflinuxfs2", "security-notice", "some-label"] }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: "123", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "123", current_state: "started")

      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "789",
                                                                           "description" => "#{affected_story_content_only_one_stack('cflinuxfs2')}",
                                                                           "labels" => ["cflinuxfs2", "security-notice", "some-other-label"] }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: "789", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "789", current_state: "started")

      subject.run
    end
  end

  context "when the stack is cflinuxfs3" do
    let(:stories_json) {
      stories = [
        {
          "id": '789',
          "description": unaffected_story_content('cflinuxfs3'),
          "labels": %w(cflinuxfs3 security-notice some-other-label)
        },
        {
          "id": '101',
          "description": affected_story_content('cflinuxfs3'),
          "labels": %w(cflinuxfs3 security-notice some-label)
        },
        {
          "id": '456',
          "description": affected_story_content_only_one_stack('cflinuxfs3'),
          "labels": %w(cflinuxfs3 security-notice some-other-label)
        }
      ]
      JSON.dump({ version: { ref: JSON.dump(stories) } })
    }

    subject { CategorizeSecurityNotices.new(tracker_client, stories_file.path, stack_receipt.path, 'cflinuxfs3') }

    before(:each) do
      allow(tracker_client).to receive(:add_label_to_story).with(anything)
      allow(tracker_client).to receive(:point_story).with(anything)
      allow(tracker_client).to receive(:change_story_state).with(anything)

      stories_file.write(stories_json)
      stories_file.close
      stack_receipt.write(receipt_content)
      stack_receipt.close
    end

    it "labels any stories unrelated to the rootfs with 'unaffected', points them with 0, and delivers them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { 'id' => '789',
                                                                           'description' => unaffected_story_content('cflinuxfs3'),
                                                                           'labels' => %w(cflinuxfs3 security-notice some-other-label) }, label: 'unaffected')
      expect(tracker_client).to receive(:point_story).with(story_id: '789', estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: '789', current_state: 'delivered')

      subject.run
    end

    it "labels any stories related to the rootfs (regardless of package version) with 'affected', points them with 0, and starts them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { 'id' => '101',
                                                                           'description' => affected_story_content('cflinuxfs3'),
                                                                           'labels' => %w(cflinuxfs3 security-notice some-label) }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: '101', estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: '101', current_state: 'started')

      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "456",
                                                                           "description" => affected_story_content_only_one_stack('cflinuxfs3'),
                                                                           "labels" => ["cflinuxfs3", "security-notice", "some-other-label"] }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: "456", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "456", current_state: "started")

      subject.run
    end
  end
end
