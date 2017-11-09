require 'json'
require 'webmock/rspec'
require 'tempfile'

require_relative '../../../tasks/categorize-security-notices/categorize-security-notices'

describe CategorizeSecurityNotices do
  let(:tracker_client) {double "tracker_client"}
  let(:stories_file) { Tempfile.new }
  let(:stack_receipt) { Tempfile.new }
  let(:story_content) do <<-STORY
                            **Product:** cflinuxfs2-acceptance
                            **Severity:** medium
                            **USN:** http://www.ubuntu.com/usn/usn-3353-1/

                            **Trusty Packages:**
                            libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.2
                            libkrb5-26-heimdal 1.6~git20131207+dfsg-1ubuntu1.3

                            **Xenial Packages:**
                            libkrb5-26-heimdal 1.7~git20150920+dfsg-4ubuntu1.16.04.1

                            ---

                            **Instructions**

                            ---

                            **Are you affected?**

                            To notify security teams that you are **not affected** by this security notice, please label this story with`unaffected`and ensure that it is finished, delivered, and accepted. Please do this at your soonest possible convenience.

                            If you **are affected** by this security notice, please accept this story once a fix is available for consumers of your product.

                            **What versions are affected?**

                            If possible, please provide affected and fixed product version information by labelling this story. Label this story `affected-VERSION` (ex. `affected-1.2.3` or `affected-43x`) to provide us with affected version information. Label this story `fixed-VERSION` (ex. `fixed-1.2.4` or `fixed-44x`) to provide fixed version information. Any number of either type of label is acceptable, and the version information can be free-form. For example, if versions 1.2.1 and 1.2.3-1.4.5 are affected by the vulnerability, and version 1.4.6 fixes it, you might label the story:
                            ````
                            affected-1.2.1  affected-1.2.3-1.4.5  fixed-1.4.6
                            ````
                            STORY
                        end

  let(:stories_json) { JSON.dump({ version: { ref: JSON.dump([ { "id": "123",
                                                                 "description": "#{story_content}",
                                                                 "labels": ["cflinuxfs2", "security-notice", "some-label"] },
                                                               { "id": "456",
                                                                 "description": "**Trusty Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n",
                                                                 "labels": ["cflinuxfs2", "security-notice", "some-other-label"] } ]) }})}

  let(:receipt_content) { "ii  libkrb5-26-heimdal:amd64           1.6~git20131207+dfsg-1ubuntu1.4            amd64        Heimdal Kerberos - libraries\n" +
                          "ii  evince   3.10.3-0ubuntu10.3\n" +
                          "ii  evince-common    3.10.2-0ubuntu10.3\n"}

  subject { CategorizeSecurityNotices.new(tracker_client, stories_file.path, stack_receipt.path) }

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
                                                                         "description" => "**Trusty Packages:**\nnginx-extras 1.4.6-1ubuntu3.8\n\n",
                                                                         "labels" => ["cflinuxfs2", "security-notice", "some-other-label"] }, label: "unaffected")
    expect(tracker_client).to receive(:point_story).with(story_id: "456", estimate: 0)
    expect(tracker_client).to receive(:change_story_state).with(story_id: "456", current_state: "delivered")

    subject.run
  end

  it "labels any stories related to the rootfs (regardless of package version) with 'affected', points them with 0, and starts them" do
    expect(tracker_client).to receive(:add_label_to_story).with(story: { "id" => "123",
                                                                         "description" => "#{story_content}",
                                                                         "labels" => ["cflinuxfs2", "security-notice", "some-label"] }, label: "affected")
    expect(tracker_client).to receive(:point_story).with(story_id: "123", estimate: 0)
    expect(tracker_client).to receive(:change_story_state).with(story_id: "123", current_state: "started")

    subject.run
  end
end
