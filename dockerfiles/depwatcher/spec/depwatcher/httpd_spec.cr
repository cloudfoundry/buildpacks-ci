require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/httpd"

Spec2.describe Depwatcher::Httpd do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("http://archive.apache.org/dist/httpd/", File.read(__DIR__+"/../fixtures/httpd.html"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "2.4.16", "2.4.17", "2.4.18", "2.4.20", "2.4.23",
        "2.4.25", "2.4.26", "2.4.27", "2.4.28", "2.4.29"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("2.4.29")
      expect(obj.ref).to eq "2.4.29"
      expect(obj.url).to eq "http://archive.apache.org/dist/httpd/httpd-2.4.29.tar.gz"
    end
  end
end
