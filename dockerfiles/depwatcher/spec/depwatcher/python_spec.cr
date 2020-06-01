require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/python"

Spec2.describe Depwatcher::Python do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://www.python.org/downloads/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/python.html")))
    client.stub_get("https://www.python.org/downloads/release/python-355/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/python-355.html")))
    client.stub_get("https://www.python.org/ftp/python/3.5.5/Python-3.5.5.tgz", nil, HTTP::Client::Response.new(200, "hello"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "2.7.2", "3.2.1", "3.2.2", "3.1.5", "2.7.3", "2.6.8", "3.2.3", "3.3.0",
        "3.2.4", "2.7.4", "3.3.1", "2.7.5", "3.2.5", "3.3.2", "2.6.9", "2.7.6",
        "3.3.3", "3.3.4", "3.3.5", "3.4.0", "3.4.1", "2.7.7", "2.7.8", "3.2.6",
        "3.3.6", "3.4.2", "2.7.9", "3.4.3", "2.7.10", "3.5.0", "2.7.11", "3.5.1",
        "3.4.4", "2.7.12", "3.5.2", "3.4.5", "2.7.13", "3.6.0", "3.5.3", "3.4.6",
        "3.6.1", "3.6.2", "3.5.4", "3.4.7", "2.7.14", "3.3.7", "3.6.3", "3.6.4",
        "3.5.5", "3.4.8"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("3.5.5")
      expect(obj.ref).to eq "3.5.5"
      expect(obj.url).to eq "https://www.python.org/ftp/python/3.5.5/Python-3.5.5.tgz"
      expect(obj.md5_digest).to eq "7c825b747d25c11e669e99b912398585"
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
