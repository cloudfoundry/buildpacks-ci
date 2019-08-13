require_relative '../../../tasks/collect-release-artifacts/cnb'

describe CNB do
  describe "#release_notes" do
    it "is a cnb which has just been added to the shim" do
      cnb = CNB.new("org.cloudfoundry.nodejs", ["new-cnb", "1"])

      expected_notes = "### Added version 1"
      expect(cnb.release_notes).to eq(expected_notes)
    end

    it "is an updated existing dependency with one update" do
      octokit = double("Octokit")
      release_object = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nPackaged binaries: \n Supported stacks:",
        :html_url => "http://foo.gov"
      )
      expect(octokit).to receive(:releases).with("cloudfoundry/npm-cnb")
        .and_return([release_object])

      cnb = CNB.new("org.cloudfoundry.npm", ["v2"], octokit)

      expected_notes = <<~NOTES
### v2
somebody

More details are [here](http://foo.gov).
      NOTES

      expect(cnb.release_notes).to eq(expected_notes)
    end

    it "is an updated existing dependency with multiple update" do
      octokit = double("Octokit")
      release_object_v2 = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nPackaged binaries: \n Supported stacks:",
        :html_url => "http://foo.gov"
      )
      release_object_v1 = OpenStruct.new(
        :name => "v1",
        :tag_name => "v1",
        :body => "somebody\nPackaged binaries: \n Supported stacks:",
        :html_url => "http://foo1.gov"
      )
      expect(octokit).to receive(:releases).with("pivotal-cf/p-snyk-cnb")
        .and_return([release_object_v2, release_object_v1])

      cnb = CNB.new("io.pivotal.snyk", ["v2", "v1"], octokit)

      expected_notes = <<~NOTES
### v2
somebody

More details are [here](http://foo.gov).

### v1
somebody

More details are [here](http://foo1.gov).
      NOTES

      expect(cnb.release_notes).to eq(expected_notes)
    end
  end

  describe "#dependencies" do
    it "describes the dependencies (when they exist) that the current version of CNB contains" do
      octokit = double("Octokit")
      release_object = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nPackaged binaries:\n- Bin1\n- Bin2\nSupported stacks:\n- Stack 1\n- Stack2",
        :html_url => "http://foo.gov"
      )
      expect(octokit).to receive(:releases).with("pivotal-cf/p-snyk-cnb")
        .and_return([release_object])

      cnb = CNB.new("io.pivotal.snyk", ["v2"], octokit)
      expected_deps= <<~DEPS
Packaged binaries:
- Bin1
- Bin2
      DEPS
      expect(cnb.dependencies).to eq(expected_deps)
    end

    it "describes the dependencies when there are no Supported stacks" do
      octokit = double("Octokit")
      release_object = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nPackaged binaries:\n- Bin1\n- Bin2\n",
        :html_url => "http://foo.gov"
      )
      expect(octokit).to receive(:releases).with("pivotal-cf/p-snyk-cnb")
        .and_return([release_object])

      cnb = CNB.new("io.pivotal.snyk", ["v2"], octokit)
      expected_deps= <<~DEPS
Packaged binaries:
- Bin1
- Bin2
      DEPS
      expect(cnb.dependencies).to eq(expected_deps)
    end

    it "returns empty string when there are no packaged dependencies" do
      octokit = double("Octokit")
      release_object = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nSupported stacks:",
        :html_url => "http://foo.gov"
      )
      expect(octokit).to receive(:releases).with("pivotal-cf/p-snyk-cnb")
        .and_return([release_object])

      cnb = CNB.new("io.pivotal.snyk", ["v2"], octokit)
      expected_deps= ""
      expect(cnb.dependencies).to eq(expected_deps)
    end
  end

  describe "#stacks" do
    it "returns the stacks that the CNB supports" do
        octokit = double("Octokit")
        release_object = OpenStruct.new(
          :name => "v2",
          :tag_name => "v2",
          :body => "somebody\nPackaged binaries:\n- Bin1\n- Bin2\nSupported stacks:\n- Stack 1\n- Stack 2\n",
          :html_url => "http://foo.gov"
        )
        expect(octokit).to receive(:releases).with("buildpack/lifecycle")
          .and_return([release_object])

        cnb = CNB.new("lifecycle", ["v2"], octokit)
        expected_deps= <<~DEPS
Supported stacks:
- Stack 1
- Stack 2
        DEPS
        expect(cnb.stacks).to eq(expected_deps)
    end

    it "returns empty string when there are no supported stacks" do
      octokit = double("Octokit")
      release_object = OpenStruct.new(
        :name => "v2",
        :tag_name => "v2",
        :body => "somebody\nPackaged binaries:\n- Bin1\n- Bin2\n",
        :html_url => "http://foo.gov"
      )
      expect(octokit).to receive(:releases).with("pivotal-cf/p-snyk-cnb")
        .and_return([release_object])

      cnb = CNB.new("io.pivotal.snyk", ["v2"], octokit)
      expected_deps= ""
      expect(cnb.stacks).to eq(expected_deps)
    end

  end
end
