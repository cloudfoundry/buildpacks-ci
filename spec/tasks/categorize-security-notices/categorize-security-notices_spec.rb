require 'json'
require 'webmock/rspec'
require 'tempfile'

require_relative '../../../tasks/categorize-security-notices/categorize-security-notices'

describe CategorizeSecurityNotices do
  let(:tracker_client) { double "tracker_client" }
  let(:davos_client) { double "davos client" }
  let(:stories_file) { Tempfile.new }
  let(:stack_receipt) { Tempfile.new }

  def story_content(stack)
    <<-STORY
                            **Product:** #{stack}
                            **Severity:** medium
                            **USN:** http://www.ubuntu.com/usn/usn-3353-1/

                            **Trusty Packages:**
                            libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.2
                            libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.3

                            **Bionic Packages:**
                            libkrb5-26-heimdal 1.7~git20150920+dfsg-4ubuntu1.18.04.1

                            ---
                            #### **Resolution Instructions**

                            ###### Step 1

                            Please click the resolution link below to acknowledge receipt of the notice.

                            ###### Step 2

                            Once you have determined whether the vulnerability affects your product, click
                            the resolution link again to provide the appropriate resolution information.

                            #### **Resolution Link**

                            [Click here to respond to this notice.](https://davos.cfapps.io/product_stories/4567)
    STORY
  end

  let(:stories_json) {
    stories = [
        {
            "id": '123',
            "description": "#{story_content('cflinuxfs2')}",
            "labels": %w(cflinuxfs2 security-notice some-label)
        },
        {
            "id": '456',
            "description": "**Trusty Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n[Click here to respond to this notice.](https://davos.cfapps.io/product_stories/1289)\n",
            "labels": %w(cflinuxfs2 security-notice some-other-label)
        },
        {
            "id": '789',
            "description": "**Bionic Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n[Click here to respond to this notice.](https://davos.cfapps.io/product_stories/1289)\n",
            "labels": %w(cflinuxfs3 security-notice some-other-label)
        },
        {
            "id": '101',
            "description": "#{story_content('cflinuxfs3')}",
            "labels": %w(cflinuxfs3 security-notice some-label)
        }
    ]
    JSON.dump({ version: { ref: JSON.dump(stories) } })
  }

  let(:receipt_content) { "ii  libkrb5-26-heimdal:amd64           1.6~git20131207+dfsg-1ubuntu1.4            amd64        Heimdal Kerberos - libraries\n" +
      "ii  evince   3.10.3-0ubuntu10.3\n" +
      "ii  evince-common    3.10.2-0ubuntu10.3\n" }

  context "when the stack is cflinuxfs2" do
    subject { CategorizeSecurityNotices.new(tracker_client, stories_file.path, stack_receipt.path, davos_client, 'cflinuxfs2') }

    before(:each) do
      allow(tracker_client).to receive(:add_label_to_story).with(anything)
      allow(tracker_client).to receive(:point_story).with(anything)
      allow(tracker_client).to receive(:change_story_state).with(anything)
      allow(davos_client).to receive(:change).with(anything, anything)

      stories_file.write(stories_json)
      stories_file.close
      stack_receipt.write(receipt_content)
      stack_receipt.close
    end

    it "labels any stories unrelated to the rootfs with 'unaffected', points them with 0, and delivers them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "456",
                                                                           "description" => "**Trusty Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n[Click here to respond to this notice.](https://davos.cfapps.io/product_stories/1289)\n",
                                                                           "labels" => ["cflinuxfs2", "security-notice", "some-other-label"] }, label: "unaffected")
      expect(tracker_client).to receive(:point_story).with(story_id: "456", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "456", current_state: "delivered")

      expect(davos_client).to receive(:change).with('1289', status: 'unaffected')

      subject.run
    end

    it "labels any stories related to the rootfs (regardless of package version) with 'affected', points them with 0, and starts them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "123",
                                                                           "description" => "#{story_content('cflinuxfs2')}",
                                                                           "labels" => ["cflinuxfs2", "security-notice", "some-label"] }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: "123", estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: "123", current_state: "started")

      expect(davos_client).to receive(:change).with('4567', status: 'acknowledged')

      subject.run
    end
  end

  context "when the stack is cflinuxfs3" do
    subject { CategorizeSecurityNotices.new(tracker_client, stories_file.path, stack_receipt.path, davos_client, 'cflinuxfs3') }

    before(:each) do
      allow(tracker_client).to receive(:add_label_to_story).with(anything)
      allow(tracker_client).to receive(:point_story).with(anything)
      allow(tracker_client).to receive(:change_story_state).with(anything)
      allow(davos_client).to receive(:change).with(anything, anything)

      stories_file.write(stories_json)
      stories_file.close
      stack_receipt.write(receipt_content)
      stack_receipt.close
    end

    it "labels any stories unrelated to the rootfs with 'unaffected', points them with 0, and delivers them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { 'id' => '789',
                                                                           'description' => "**Bionic Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n[Click here to respond to this notice.](https://davos.cfapps.io/product_stories/1289)\n",
                                                                           'labels' => %w(cflinuxfs3 security-notice some-other-label) }, label: 'unaffected')
      expect(tracker_client).to receive(:point_story).with(story_id: '789', estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: '789', current_state: 'delivered')

      expect(davos_client).to receive(:change).with('1289', status: 'unaffected')

      subject.run
    end

    it "labels any stories related to the rootfs (regardless of package version) with 'affected', points them with 0, and starts them" do
      expect(tracker_client).to receive(:add_label_to_story).with(story: { 'id' => '101',
                                                                           'description' => "#{story_content('cflinuxfs3')}",
                                                                           'labels' => %w(cflinuxfs3 security-notice some-label) }, label: "affected")
      expect(tracker_client).to receive(:point_story).with(story_id: '101', estimate: 0)
      expect(tracker_client).to receive(:change_story_state).with(story_id: '101', current_state: 'started')

      expect(davos_client).to receive(:change).with('4567', status: 'acknowledged')

      subject.run
    end
  end
end
