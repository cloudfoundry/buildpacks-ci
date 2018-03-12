require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/nginx"

Spec2.describe Depwatcher::Nginx do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://api.github.com/repos/nginx/nginx/tags", File.read(__DIR__+"/../fixtures/github_nginx.json"))
    client.stub_get("http://nginx.org/en/download.html", File.read(__DIR__+"/../fixtures/nginx.html"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "1.13.0", "1.13.1", "1.13.2", "1.13.3", "1.13.4", "1.13.5", "1.13.6", "1.13.7", "1.13.8", "1.13.9"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("1.12.2")
      expect(obj.ref).to eq "1.12.2"
      expect(obj.url).to eq "http://nginx.org/download/nginx-1.12.2.tar.gz"
      expect(obj.pgp).to eq "http://nginx.org/download/nginx-1.12.2.tar.gz.asc"
    end
  end
end
