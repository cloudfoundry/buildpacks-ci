require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/python"

Spec2.describe Depwatcher::Python do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://www.python.org/downloads/", HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/python.html")))
    client.stub_get("https://www.python.org/downloads/release/python-355/", HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/python-355.html")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "3.6.1", "3.6.2", "3.5.4", "3.4.7", "2.7.14", "3.3.7", "3.6.3",
        "3.6.4", "3.5.5", "3.4.8"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("3.5.5")
      expect(obj.ref).to eq "3.5.5"
      expect(obj.url).to eq "https://www.python.org/ftp/python/3.5.5/Python-3.5.5.tgz"
      expect(obj.md5).to eq "7c825b747d25c11e669e99b912398585"
    end
  end
end
