require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/npm"

Spec2.describe Depwatcher::Npm do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://registry.npmjs.com/yarn/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/npm_yarn.json")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("yarn").map(&.ref)).to eq [
        "1.0.2", "1.1.0", "1.2.0", "1.2.1", "1.3.1", "1.3.2", "1.4.0", "1.5.0", "1.5.1", "1.6.0"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("yarn", "1.2.1")
      expect(obj.ref).to eq "1.2.1"
      expect(obj.url).to eq "https://registry.npmjs.org/yarn/-/yarn-1.2.1.tgz"
      expect(obj.sha1).to eq "0d628dc01438881a1663a6f83cbf7ac5db7a75fc"
    end
  end
end
