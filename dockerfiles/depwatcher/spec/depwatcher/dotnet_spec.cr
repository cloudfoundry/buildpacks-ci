require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/dotnet"

Spec2.describe Depwatcher::Dotnet do
  let(client) {HTTPClientMock.new}
  subject {described_class.new.tap {|s| s.client = client}}
  before do
    client.stub_get("https://api.github.com/repos/dotnet/cli/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/dotnet_releases.json")))
    client.stub_get("https://api.github.com/repos/dotnet/cli/tags", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/dotnet_tags.json")))
  end

  describe "#check" do
    it "returns dotnet release versions sorted" do
      expect(subject.check().map(&.ref)).to eq [
        "1.0.1", "1.0.3", "1.0.4", "1.1.4", "1.1.5", "1.1.6",
        "1.1.7", "1.1.8", "1.1.9", "2.0.2", "2.0.3", "2.1.2",
        "2.1.3", "2.1.4", "2.1.100", "2.1.101", "2.1.102",
        "2.1.103", "2.1.104", "2.1.105", "2.1.200", "2.1.300"
      ]
    end
  end

  describe "#in" do
    it "returns a dotnet release" do
      obj = subject.in("2.1.200")
      expect(obj.ref).to eq "2.1.200"
      expect(obj.url).to eq "https://github.com/dotnet/cli"
      expect(obj.git_commit_sha).to eq "2edba8d7f10739031100193636112628263f669c"
    end
  end
end
