require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/pypi"

Spec2.describe Depwatcher::Pypi do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://pypi.python.org/pypi/setuptools/json", File.read(__DIR__+"/../fixtures/setuptools.json"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("setuptools").map(&.ref)).to eq [
        "38.2.0", "38.2.1", "38.2.3", "38.2.4", "38.2.5", "38.3.0", "38.4.0",
        "38.4.1", "38.5.0", "38.5.1"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("setuptools", "38.4.1")
      expect(obj.ref).to eq "38.4.1"
      expect(obj.url).to eq "https://pypi.python.org/packages/d7/18/ef605d86063c11555d497a5f049709d6a90c5f8232bd6748a692794c10b7/setuptools-38.4.1.zip"
      expect(obj.md5_digest).to eq "cef139c22bbc54f40dc4e93b1b48da37"
    end
  end
end
