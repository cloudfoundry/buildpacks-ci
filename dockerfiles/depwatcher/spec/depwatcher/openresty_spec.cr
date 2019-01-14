require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/openresty"

Spec2.describe Depwatcher::Openresty do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/openresty/openresty/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/github_openresty.json")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
       "1.11.2.5", "1.13.6.1", "1.13.6.2",
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("1.13.6.2")
      expect(obj.ref).to eq "1.13.6.2"
      expect(obj.url).to eq "http://openresty.org/download/openresty-1.13.6.2.tar.gz"
      expect(obj.pgp).to eq "http://openresty.org/download/openresty-1.13.6.2.tar.gz.asc"
    end
  end
end
