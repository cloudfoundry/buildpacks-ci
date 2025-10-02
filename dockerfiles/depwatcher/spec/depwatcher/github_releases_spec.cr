require "spec"
require "file_utils"
require "./httpclient_mock"
require "../../src/depwatcher/github_releases"

describe Depwatcher::GithubReleases do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      subject.check("yarnpkg/yarn", false).map(&.ref).should eq ["1.5.1", "1.6.0"]
    end

    it "returns pre-releases and real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      subject.check("yarnpkg/yarn", true).map(&.ref).should eq ["0.0.1", "1.5.1", "1.6.0"]
    end

    it "doesn't return alpha and rc releases" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      subject.check("composer/composer", true).map(&.ref).should eq ["1.10.6", "1.10.7", "1.10.8"]
    end
  end

  describe "#in" do
    it "returns a release object for the version with binary" do
      dirname = File.join(Dir.tempdir, "github_releases_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      obj = subject.in("yarnpkg/yarn", "tar.gz", "1.5.1", dirname)
      obj.ref.should eq "1.5.1"
      obj.url.should eq "https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz"
      obj.sha256.should eq "797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"
      
      FileUtils.rm_rf dirname
    end

    it "downloads the file with binary" do
      dirname = File.join(Dir.tempdir, "github_releases_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      obj = subject.in("yarnpkg/yarn", "tar.gz", "1.5.1", dirname)
      hash = OpenSSL::Digest.new("SHA256")
      hash.update(File.read(File.join(dirname, "yarn-v1.5.1.tar.gz")))
      hash.final.hexstring.should eq obj.sha256
      
      FileUtils.rm_rf dirname
    end

    it "returns a release object for the version with source code" do
      dirname = File.join(Dir.tempdir, "github_releases_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      obj = subject.in("yarnpkg/yarn", "1.5.1", dirname)
      obj.ref.should eq "1.5.1"
      obj.url.should eq "https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz"
      obj.sha256.should eq "04d4ca87acce59d80d59e00e850e4bbc3a996aa8761fec218bcba0beab2412bd"
      
      FileUtils.rm_rf dirname
    end

    it "downloads the file with source code" do
      dirname = File.join(Dir.tempdir, "github_releases_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/yarnpkg/yarn/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_yarn.json")))
      client.stub_get("https://api.github.com/repos/composer/composer/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_composer.json")))
      client.stub_get("https://github.com/yarnpkg/yarn/releases/download/v1.5.1/yarn-v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      client.stub_get("https://github.com/yarnpkg/yarn/archive/v1.5.1.tar.gz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "different dummy data"))
      subject = Depwatcher::GithubReleases.new.tap { |s| s.client = client }
      
      obj = subject.in("yarnpkg/yarn", "1.5.1", dirname)
      hash = OpenSSL::Digest.new("SHA256")
      hash.update(File.read(File.join(dirname, "v1.5.1.tar.gz")))
      hash.final.hexstring.should eq obj.sha256
      
      FileUtils.rm_rf dirname
    end
  end
end
