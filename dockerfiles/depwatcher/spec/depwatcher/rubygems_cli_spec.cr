require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/rubygems"

Spec2.describe Depwatcher::Rubygems do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://rubygems.org/api/v1/versions/abn_search.json", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/abn_search.json")))
    client.stub_get("https://rubygems.org/api/v2/rubygems/abn_search/versions/0.0.5.json", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/abn_search_0.0.5.json")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check("abn_search").map(&.ref)).to eq [
        "0.0.1", "0.0.2", "0.0.3", "0.0.5", "0.0.6", "0.0.7", "0.0.9"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("abn_search", "0.0.5")
      expect(obj.ref).to eq "0.0.5"
      expect(obj.sha256).to eq "17ab70feebc0a0265d102665b5dd66189eeab6d7aa3b3090cb04dfae87834c9b"
    end
  end
end
