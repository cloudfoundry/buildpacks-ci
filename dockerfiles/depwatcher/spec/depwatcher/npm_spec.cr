require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/npm"

describe Depwatcher::Npm do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://registry.npmjs.com/yarn/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/npm_yarn.json")))
      subject = Depwatcher::Npm.new.tap { |s| s.client = client }
      
      subject.check("yarn").map(&.ref).should eq [
        "1.0.2", "1.1.0", "1.2.0", "1.2.1", "1.3.1", "1.3.2", "1.4.0", "1.5.0", "1.5.1", "1.6.0"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://registry.npmjs.com/yarn/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/npm_yarn.json")))
      subject = Depwatcher::Npm.new.tap { |s| s.client = client }
      
      obj = subject.in("yarn", "1.2.1")
      obj.ref.should eq "1.2.1"
      obj.url.should eq "https://registry.npmjs.org/yarn/-/yarn-1.2.1.tgz"
      obj.sha1.should eq "0d628dc01438881a1663a6f83cbf7ac5db7a75fc"
    end
  end
end
