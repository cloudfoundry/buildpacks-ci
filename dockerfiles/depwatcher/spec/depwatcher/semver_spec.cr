require "spec"
require "../../src/depwatcher/semver.cr"

describe Semver do
    it "returns normal semantic version" do
      version = Semver.new("1.2.3")
      version.major.should eq(1)
      version.minor.should eq(2)
      version.patch.should eq(3)
      version.metadata.should be_nil
    end

    it "returns successfully with no patch included" do
      version = Semver.new("1.2")
      version.major.should eq(1)
      version.minor.should eq(2)
      version.patch.should eq(0)
      version.metadata.should be_nil
    end

    it "returns successfully with metadata included" do
      version = Semver.new("1.2.3-alpha")
      version.major.should eq(1)
      version.minor.should eq(2)
      version.patch.should eq(3)
      version.metadata.should eq("-alpha")
    end

    it "returns successfully with no patch included" do
      version = Semver.new("1.2-alpha")
      version.major.should eq(1)
      version.minor.should eq(2)
      version.patch.should eq(0)
      version.metadata.should eq("-alpha")
    end

    it "returns error with a non-semantic version" do
      expect_raises(ArgumentError, "Not a semantic version: \"VERSION1\"") { Semver.new("VERSION1") }
    end

  describe "<==>" do
    it "compares using > correctly" do
      (Semver.new("1.1.2") > Semver.new("1.1.1")).should be_true
      (Semver.new("1.2.0") > Semver.new("1.1.1")).should be_true
      (Semver.new("2.0.0") > Semver.new("1.1.1")).should be_true
    end

    it "compares using < correctly" do
      (Semver.new("1.0.0") < Semver.new("1.0.1")).should be_true
      (Semver.new("1.0.1") < Semver.new("1.1.0")).should be_true
      (Semver.new("1.1.1") < Semver.new("2.0.0")).should be_true
    end

    it "compares using == correctly" do
      (Semver.new("1.1.1") == Semver.new("1.1.1")).should be_true
      (Semver.new("1.1.0") == Semver.new("1.1.0")).should be_true
    end
  end

  describe "is_final_release?" do
    it "returns true for final release versions" do
      Semver.new("1.0.0").is_final_release?.should be_true
    end
    it "returns false for non-final release versions" do
      Semver.new("1.0.0.dev1").is_final_release?.should be_false
      Semver.new("1.0.0-alpha").is_final_release?.should be_false
      Semver.new("1.2.dev").is_final_release?.should be_false
    end
  end
end

describe SemverFilter do
  describe "match" do
    it "returns true when only major is specified and major version matches" do
      versionfilter = SemverFilter.new("1.X.X")
      versionfilter.match(Semver.new("1.2.3")).should be_true
      versionfilter.match(Semver.new("1.32.3")).should be_true
      versionfilter.match(Semver.new("1.32")).should be_true
      versionfilter.match(Semver.new("1.22.3-dev")).should be_true
      versionfilter.match(Semver.new("1.22.3-dev.3333")).should be_true
    end

    it "returns false when only major is specified and major version doesn't match" do
      versionfilter = SemverFilter.new("1.X.X")
      versionfilter.match(Semver.new("2.2.3")).should be_false
      versionfilter.match(Semver.new("2.32.3")).should be_false
      versionfilter.match(Semver.new("2.32")).should be_false
      versionfilter.match(Semver.new("2.22.3-dev")).should be_false
      versionfilter.match(Semver.new("2.22.3-dev.3333")).should be_false
    end

    it "returns true when minor and major are specified and both match" do
      versionfilter = SemverFilter.new("1.2.X")
      versionfilter.match(Semver.new("1.2.3")).should be_true
      versionfilter.match(Semver.new("1.2.33")).should be_true
      versionfilter.match(Semver.new("1.2")).should be_true
      versionfilter.match(Semver.new("1.2.3-dev")).should be_true
      versionfilter.match(Semver.new("1.2.333-dev.3333")).should be_true
    end

    it "returns false when minor and major are specified and minor version doesn't match" do
      versionfilter = SemverFilter.new("1.2.X")
      versionfilter.match(Semver.new("1.3.3")).should be_false
      versionfilter.match(Semver.new("1.32.3")).should be_false
      versionfilter.match(Semver.new("1.3")).should be_false
      versionfilter.match(Semver.new("1.32.3-dev")).should be_false
      versionfilter.match(Semver.new("1.32.3-dev.3333")).should be_false
    end

    it "matches appropriately minor and major are specified and patch contains number and one or more wildcards" do
      versionfilter = SemverFilter.new("1.2.3XX")
      versionfilter.match(Semver.new("1.2.3")).should be_false
      versionfilter.match(Semver.new("1.2.34")).should be_false
      versionfilter.match(Semver.new("1.2.425")).should be_false
      versionfilter.match(Semver.new("1.2.345")).should be_true
      versionfilter.match(Semver.new("1.2.3456")).should be_true
    end

    it "returns true when major, minor, and patch are specified and all match" do
      versionfilter = SemverFilter.new("1.2.3")
      versionfilter.match(Semver.new("1.2.3")).should be_true
      versionfilter.match(Semver.new("1.2.3-dev")).should be_true
      versionfilter.match(Semver.new("1.2.3-dev.3333")).should be_true
    end

    it "returns false when major, minor, and patch are specified and patch doesn't match" do
      versionfilter = SemverFilter.new("1.2.3")
      versionfilter.match(Semver.new("1.2")).should be_false
      versionfilter.match(Semver.new("1.2.32")).should be_false
      versionfilter.match(Semver.new("1.2.33-dev")).should be_false
      versionfilter.match(Semver.new("1.2.34-dev.3333")).should be_false
    end
  end
end
