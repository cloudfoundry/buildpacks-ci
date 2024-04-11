require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/httpd"

Spec2.describe Depwatcher::Httpd do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/apache/httpd/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd_tags.json")))
    client.stub_get("https://archive.apache.org/dist/httpd-.*tar/.bz2.*tar\.bz2\.sha256", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd.sha256")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["2.4.40", "2.4.41", "2.4.42", "2.4.43", "2.4.44", 
      "2.4.45", "2.4.46", "2.4.47", "2.4.48", "2.4.49", "2.4.50", "2.4.51", "2.4.52", "2.4.53", 
      "2.4.54", "2.4.55", "2.4.56", "2.4.57", "2.4.58", "2.4.59"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("2.4.29")
      expect(obj.ref).to eq "2.4.29"
      expect(obj.url).to eq "https://dlcdn.apache.org/httpd/httpd-2.4.29.tar.bz2"
      expect(obj.sha256).to eq "777753a5a25568a2a27428b2214980564bc1c38c1abf9ccc7630b639991f7f00"
    end
  end
end
