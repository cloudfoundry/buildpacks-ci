require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/github_releases"

Spec2.describe Depwatcher::GithubReleases do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", File.read(__DIR__+"/../fixtures/yarn.json"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("yarnpkg/yarn").map(&.ref)).to eq [
        "0.24.6", "0.25.3", "0.25.4", "0.26.0", "0.26.1", "0.27.0", "0.27.1",
        "0.27.2", "0.27.3", "0.27.4", "0.27.5", "1.0.0 ! 🎉", "1.0.1", "1.0.2", "1.1.0",
        "1.1.0-exp.2", "1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.3.2"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("yarnpkg/yarn", "1.2.1")
      expect(obj.ref).to eq "1.2.1"
      expect(obj.url).to eq "https://github.com/yarnpkg/yarn/releases/download/v1.2.1/yarn-v1.2.1.tar.gz"
    end
  end
end
