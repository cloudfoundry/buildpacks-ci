require "spec2"
require "file_utils"
require "./httpclient_mock"
require "../../src/depwatcher/github_releases"

Spec2.describe Depwatcher::GithubReleases do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
    client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
    client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
    client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("yarnpkg/yarn", false).map(&.ref)).to eq ["1.5.1", "1.6.0"]
    end

    it "returns pre-releases and real releases sorted" do
      expect(subject.check("yarnpkg/yarn", true).map(&.ref)).to eq ["0.0.1", "1.5.1", "1.6.0"]
    end

    it "doesn't return alpha and rc releases" do
      expect(subject.check("composer/composer", true).map(&.ref)).to eq ["1.10.6", "1.10.7", "1.10.8"]
    end
  end

  describe "#in" do
    let(dirname) {
      File.join(Dir.tempdir, "github_releases_spec-" + Random.new().urlsafe_base64())
    }
    before do
      Dir.mkdir dirname
    end

    after do
      FileUtils.rm_rf dirname
    end

    context "when fetching a binary" do
      it "returns a release object for the version" do
        obj = subject.in("yarnpkg/yarn", "tar.gz", "1.5.1", dirname)
        expect(obj.ref).to eq "1.5.1"
        expect(obj.url).to eq "https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz"
        expect(obj.sha256).to eq "797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"
      end

      it "downloads the file" do
        obj = subject.in("yarnpkg/yarn", "tar.gz", "1.5.1", dirname)
        hash = OpenSSL::Digest.new("SHA256")
        hash.update(File.read(File.join(dirname, "yarn-v1.5.1.tar.gz")))
        expect(hash.hexdigest).to eq obj.sha256
      end
    end

    context "when fetching raw source code" do
      it "returns a release object for the version" do
        obj = subject.in("yarnpkg/yarn", "1.5.1", dirname)
        expect(obj.ref).to eq "1.5.1"
        expect(obj.url).to eq "https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz"
        expect(obj.sha256).to eq "04d4ca87acce59d80d59e00e850e4bbc3a996aa8761fec218bcba0beab2412bd"
      end

      it "downloads the file" do
        obj = subject.in("yarnpkg/yarn", "1.5.1", dirname)
        hash = OpenSSL::Digest.new("SHA256")
        hash.update(File.read(File.join(dirname, "v1.5.1.tar.gz")))
        expect(hash.hexdigest).to eq obj.sha256
      end
    end
  end
end
