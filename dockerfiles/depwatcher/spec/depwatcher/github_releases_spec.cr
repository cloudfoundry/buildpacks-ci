require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/github_releases"

Spec2.describe Depwatcher::GithubReleases do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/gh_yarn.json")))
    client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Client::Response.new(200, body_io: IO::Memory.new("dummy data")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("yarnpkg/yarn").map(&.ref)).to eq ["1.5.1", "1.6.0"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("yarnpkg/yarn", "tar.gz", "1.5.1")
      expect(obj.ref).to eq "1.5.1"
      expect(obj.url).to eq "https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz"
      expect(obj.sha256).to eq "797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"
    end
  end
end
