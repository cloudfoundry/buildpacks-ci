require "spec"
require "file_utils"
require "./httpclient_mock"
require "../../src/depwatcher/icu"

describe Depwatcher::Icu do
  describe "#check" do
    it "returns sorted versions as valid semvers" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/unicode-org/icu/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_icu.json")))
      client.stub_get("https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      subject = Depwatcher::Icu.new.tap { |s| s.client = client }
      
      subject.check().map(&.ref).should eq ["4.8.2", "64.2.0", "65.1.0"]
    end
  end

  describe "#in" do
    it "returns a release object for the version" do
      dirname = File.join(Dir.tempdir, "icu_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/unicode-org/icu/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_icu.json")))
      client.stub_get("https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      subject = Depwatcher::Icu.new.tap { |s| s.client = client }
      
      obj = subject.in("65.1.0", dirname)
      obj.ref.should eq "65.1.0"
      obj.url.should eq "https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz"
      obj.sha256.should eq "797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"
      
      FileUtils.rm_rf dirname
    end

    it "downloads the file" do
      dirname = File.join(Dir.tempdir, "icu_spec-" + Random.new().urlsafe_base64())
      Dir.mkdir dirname
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/unicode-org/icu/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_icu.json")))
      client.stub_get("https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
      subject = Depwatcher::Icu.new.tap { |s| s.client = client }
      
      obj = subject.in("65.1.0", dirname)
      hash = OpenSSL::Digest.new("SHA256")
      hash.update(File.read(File.join(dirname, "icu4c-65_1-src.tgz")))
      hash.final.hexstring.should eq obj.sha256
      
      FileUtils.rm_rf dirname
    end
  end
end
