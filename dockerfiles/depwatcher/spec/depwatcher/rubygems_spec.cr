require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/rubygems_cli"

Spec2.describe Depwatcher::RubygemsCli do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://rubygems.org/pages/download", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rubygems.html")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["2.7.6"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("2.7.6")
      expect(obj.ref).to eq "2.7.6"
      expect(obj.url).to eq "https://rubygems.org/rubygems/rubygems-2.7.6.tgz"
    end
  end
end
