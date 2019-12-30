require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/pypi"

Spec2.describe Depwatcher::Pypi do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://pypi.org/pypi/setuptools/json", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/setuptools.json")))
  end

  describe "#check" do
    it "returns final releases sorted" do
      expect(subject.check("setuptools").map(&.ref)).to eq [
        "38.2.5", "38.3.0", "38.4.0", "38.4.1", "38.5.0", "38.5.1", "38.5.2", "38.6.1", "39.0.0", "39.0.1"
      ]
    end

    it "returns final releases including >= 10.x sorted for pip" do
      client.stub_get("https://pypi.org/pypi/pip/json", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/pip.json")))
      expect(subject.check("pip").map(&.ref)).to eq [
        "8.0.3", "8.1.0", "8.1.1", "8.1.2", "9.0.0", "9.0.1", "9.0.2", "9.0.3", "10.0.0", "10.0.1"
      ]
    end
  end

  describe "#in" do
    it "returns the latest final release" do
      obj = subject.in("setuptools", "38.4.1")
      expect(obj.ref).to eq "38.4.1"
      expect(obj.url).to eq "https://files.pythonhosted.org/packages/d7/18/ef605d86063c11555d497a5f049709d6a90c5f8232bd6748a692794c10b7/setuptools-38.4.1.zip"
      expect(obj.md5_digest).to eq "cef139c22bbc54f40dc4e93b1b48da37"
    end
  end
end
