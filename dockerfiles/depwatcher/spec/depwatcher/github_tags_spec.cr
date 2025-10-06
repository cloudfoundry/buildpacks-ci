require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/github_tags"

describe Depwatcher::GithubTags do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/dotnet/cli/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_tags.json")))
      client.stub_get("https://github.com/dotnet/cli/archive/2edba8d7f10739031100193636112628263f669c.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
      subject = Depwatcher::GithubTags.new.tap {|s| s.client = client}
      
      subject.check("dotnet/cli", "^v[0-9]").map(&.ref).should eq [
        "v1.0.4", "v1.1.0", "v1.1.0-preview1-005051", "v1.1.0-preview1-005077", "v1.1.3",
        "v1.1.4", "v1.1.5", "v1.1.6", "v1.1.7", "v1.1.8", "v1.1.9", "v2.0.0", "v2.0.0-preview1",
        "v2.0.0-preview2", "v2.0.2", "v2.0.3", "v2.1.1-preview-007183", "v2.1.2", "v2.1.3",
        "v2.1.4", "v2.1.100", "v2.1.101", "v2.1.102", "v2.1.103", "v2.1.104", "v2.1.105",
        "v2.1.200", "v2.1.300-preview1-008174", "v2.1.300-preview2-008530", "v2.1.300-rc1-008673"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/dotnet/cli/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_tags.json")))
      client.stub_get("https://github.com/dotnet/cli/archive/2edba8d7f10739031100193636112628263f669c.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
      subject = Depwatcher::GithubTags.new.tap {|s| s.client = client}
      
      obj = subject.in("dotnet/cli", "v2.1.200")
      obj.ref.should eq "v2.1.200"
      obj.url.should eq "https://github.com/dotnet/cli/archive/2edba8d7f10739031100193636112628263f669c.tar.gz"
      obj.git_commit_sha.should eq "2edba8d7f10739031100193636112628263f669c"
      obj.sha256.should eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
