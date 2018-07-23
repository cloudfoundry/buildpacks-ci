require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/dotnet"

Spec2.describe Depwatcher::Dotnet do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }

  before do
    client.stub_get(
      "https://api.github.com/repos/dotnet/cli/tags?per_page=1000",
      nil,
      HTTP::Client::Response.new(
        200,
        File.read(__DIR__ + "/../fixtures/dotnet_tags.json")
      )
    )
  end

  describe "#check" do
    it "returns dotnet release versions sorted" do
      expect(subject.check(".*\\+dependencies").map(&.ref)).to eq [
        "2.1.103", "2.1.104", "2.1.105", "2.1.200", "2.1.301",
      ]
    end
  end

  describe "#in" do
    it "returns a dotnet release" do
      obj = subject.in("2.1.301", ".*\\+dependencies")
      expect(obj.ref).to eq "2.1.301"
      expect(obj.url).to eq "https://github.com/dotnet/cli"
      expect(obj.git_commit_sha).to eq "2a1f1c6d30c73c1bce0b557ebbdfba1008e9ae63"
    end
  end
end
