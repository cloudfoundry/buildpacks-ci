require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/github_tags"

Spec2.describe Depwatcher::GithubTags do
  let(client) {HTTPClientMock.new}
  subject {described_class.new.tap {|s| s.client = client}}
  before do
    client.stub_get("https://api.github.com/repos/dotnet/cli/tags", File.read(__DIR__ + "/../fixtures/dotnet.json"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("dotnet/cli", "^v[0-9]").map(&.ref)).to eq [
        "v2.1.100",
        "v2.1.101",
        "v2.1.102",
        "v2.1.103",
        "v2.1.104",
        "v2.1.105",
        "v2.1.200",
        "v2.1.300-preview1-008174",
        "v2.1.300-preview2-008530",
        "v2.1.300-rc1-008673"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("dotnet/cli", "v2.1.200")
      expect(obj.ref).to eq "v2.1.200"
      expect(obj.url).to eq "https://api.github.com/repos/dotnet/cli/tarball/v2.1.200"
    end
  end
end
