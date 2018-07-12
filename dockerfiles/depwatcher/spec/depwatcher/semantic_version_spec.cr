require "spec2"
require "../../src/depwatcher/semantic_version.cr"

Spec2.describe SemanticVersion do
    it "returns normal semantic version" do
      version = SemanticVersion.new("1.2.3")
      expect(version.major).to eq 1
      expect(version.minor).to eq 2
      expect(version.patch).to eq 3
      expect(version.metadata).to be_nil
    end

    it "returns successfully with no patch included" do
      version = SemanticVersion.new("1.2")
      expect(version.major).to eq 1
      expect(version.minor).to eq 2
      expect(version.patch).to eq 0
      expect(version.metadata).to be_nil
    end

    it "returns successfully with no patch included" do
      version = SemanticVersion.new("1.2.3-alpha")
      expect(version.major).to eq 1
      expect(version.minor).to eq 2
      expect(version.patch).to eq 0
      expect(version.metadata).to eq "-alpha"
    end

    it "returns successfully with no patch included" do
      version = SemanticVersion.new("1.2-alpha")
      expect(version.major).to eq 1
      expect(version.minor).to eq 2
      expect(version.patch).to eq 0
      expect(version.metadata).to eq "-alpha"
    end

    it "returns error with a non-semantic version" do
      expect{ SemanticVersion.new("VERSION1") }.to raise_error ArgumentError, "Not a semantic version: \"VERSION1\""
    end

  describe "<==>" do
    it "compares using > correctly" do
      expect(SemanticVersion.new("1.1.2")).to_be > SemanticVersion.new("1.1.1")
      expect(SemanticVersion.new("1.2.0")).to_be > SemanticVersion.new("1.1.1")
      expect(SemanticVersion.new("2.0.0")).to_be > SemanticVersion.new("1.1.1")
    end

    it "compares using < correctly" do
      expect(SemanticVersion.new("1.0.0")).to_be < SemanticVersion.new("1.0.1")
      expect(SemanticVersion.new("1.0.1")).to_be < SemanticVersion.new("1.1.0")
      expect(SemanticVersion.new("1.1.1")).to_be < SemanticVersion.new("2.0.0")
    end

    it "compares using == correctly" do
      expect(SemanticVersion.new("1.1.1")).to_be == SemanticVersion.new("1.1.1")
      expect(SemanticVersion.new("1.1")).to_be == SemanticVersion.new("1.1.0")
    end
  end

  describe "is_final_release?" do
    it "returns true for final release versions" do
      expect(SemanticVersion.new("1.0.0").is_final_release?).to be_true
    end
    it "returns false for non-final release versions" do
      expect(SemanticVersion.new("1.0.0.dev1").is_final_release?).to be_false
      expect(SemanticVersion.new("1.0.0-alpha").is_final_release?).to be_false
      expect(SemanticVersion.new("1.2.dev").is_final_release?).to be_false
    end
  end
end

Spec2.describe SemanticVersionFilter do
  describe "match" do
    it "returns true when only major is specified and major version matches" do
      versionfilter = SemanticVersionFilter.new("1.X.X")
      expect(versionfilter.match(SemanticVersion.new("1.2.3"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.32.3"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.32"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.22.3-dev"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.22.3-dev.3333"))).to be_true
    end

    it "returns false when only major is specified and major version doesn't match" do
      versionfilter = SemanticVersionFilter.new("1.X.X")
      expect(versionfilter.match(SemanticVersion.new("2.2.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("2.32.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("2.32"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("2.22.3-dev"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("2.22.3-dev.3333"))).to be_false
    end

    it "returns true when minor and major are specified and both match" do
      versionfilter = SemanticVersionFilter.new("1.2.X")
      expect(versionfilter.match(SemanticVersion.new("1.2.3"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.33"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.3-dev"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.333-dev.3333"))).to be_true
    end

    it "returns false when minor and major are specified and minor version doesn't match" do
      versionfilter = SemanticVersionFilter.new("1.2.X")
      expect(versionfilter.match(SemanticVersion.new("1.3.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.32.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.32.3-dev"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.32.3-dev.3333"))).to be_false
    end

    it "matches appropriately minor and major are specified and patch contains number and one or more wildcards" do
      versionfilter = SemanticVersionFilter.new("1.2.3XX")
      expect(versionfilter.match(SemanticVersion.new("1.2.3"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.34"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.425"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.345"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.3456"))).to be_true
    end

    it "returns true when major, minor, and patch are specified and all match" do
      versionfilter = SemanticVersionFilter.new("1.2.3")
      expect(versionfilter.match(SemanticVersion.new("1.2.3"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.3-dev"))).to be_true
      expect(versionfilter.match(SemanticVersion.new("1.2.3-dev.3333"))).to be_true
    end

    it "returns false when major, minor, and patch are specified and patch doesn't match" do
      versionfilter = SemanticVersionFilter.new("1.2.3")
      expect(versionfilter.match(SemanticVersion.new("1.2"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.32"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.33-dev"))).to be_false
      expect(versionfilter.match(SemanticVersion.new("1.2.34-dev.3333"))).to be_false
    end
  end
end
