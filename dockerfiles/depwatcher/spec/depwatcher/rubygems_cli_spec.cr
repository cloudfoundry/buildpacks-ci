require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/rubygems_cli"

describe Depwatcher::RubygemsCli do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::RubygemsCli.new.tap { |s| s.client = client }
      client.stub_get("https://rubygems.org/pages/download", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rubygems.html")))
      
      subject.check.map(&.ref).should eq ["2.7.6"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::RubygemsCli.new.tap { |s| s.client = client }
      client.stub_get("https://rubygems.org/pages/download", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rubygems.html")))
      
      obj = subject.in("2.7.6")
      obj.ref.should eq "2.7.6"
      obj.url.should eq "https://rubygems.org/rubygems/rubygems-2.7.6.tgz"
    end
  end
end
