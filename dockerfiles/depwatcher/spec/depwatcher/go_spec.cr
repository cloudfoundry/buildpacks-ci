require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/go"

Spec2.describe Depwatcher::Go do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://golang.org/dl/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/golang.html")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "1.2.2", "1.3", "1.3.1", "1.3.2", "1.3.3", "1.4", "1.4.1", "1.4.2",
        "1.4.3", "1.5", "1.5.1", "1.5.2", "1.5.3", "1.5.4", "1.6", "1.6.1",
        "1.6.2", "1.6.3", "1.6.4", "1.7", "1.7.1", "1.7.3", "1.7.4", "1.7.5",
        "1.7.6", "1.8", "1.8.1", "1.8.2", "1.8.3", "1.8.4", "1.8.5", "1.8.6",
        "1.8.7", "1.9", "1.9.1", "1.9.2", "1.9.3", "1.9.4", "1.10"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("1.8.4")
      expect(obj.ref).to eq "1.8.4"
      expect(obj.url).to eq "https://dl.google.com/go/go1.8.4.src.tar.gz"
      expect(obj.sha256).to eq "abf1b2e5ae2a4845f3d2eac00c7382ff209e2c132dc35b7ce753da9b4f52e59f"
    end
  end
end
