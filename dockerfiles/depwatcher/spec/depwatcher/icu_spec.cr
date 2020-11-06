require "spec2"
require "file_utils"
require "./httpclient_mock"
require "../../src/depwatcher/icu"

Spec2.describe Depwatcher::Icu do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/unicode-org/icu/releases", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/gh_icu.json")))
    client.stub_get("https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz", HTTP::Headers{"Accept" => "application/octet-stream"}, HTTP::Client::Response.new(200, body: "dummy data"))
  end

  describe "#check" do
    it "returns sorted versions as valid semvers" do
      expect(subject.check().map(&.ref)).to eq ["4.8.2", "64.2.0", "65.1.0"]
    end
  end

  describe "#in" do
    let(dirname) {
      File.join(Dir.tempdir, "icu_spec-" + Random.new().urlsafe_base64())
    }
    before do
      Dir.mkdir dirname
    end

    after do
      FileUtils.rm_rf dirname
    end

    it "returns a release object for the version" do
      obj = subject.in("65.1.0", dirname)
      expect(obj.ref).to eq "65.1.0"
      expect(obj.url).to eq "https://github.com/unicode-org/icu/releases/download/release-65-1/icu4c-65_1-src.tgz"
      expect(obj.sha256).to eq "797bb0abff798d7200af7685dca7901edffc52bf26500d5bd97282658ee24152"
    end

    it "downloads the file" do
      obj = subject.in("65.1.0", dirname)
      hash = OpenSSL::Digest.new("SHA256")
      hash.update(File.read(File.join(dirname, "icu4c-65_1-src.tgz")))
      expect(hash.hexdigest).to eq obj.sha256
    end
  end
end
