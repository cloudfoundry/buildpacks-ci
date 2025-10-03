require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/httpd"

describe Depwatcher::Httpd do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/apache/httpd/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd_tags.json")))
      client.stub_get("https://archive.apache.org/dist/httpd-.*tar/.bz2.*tar\.bz2\.sha256", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd.sha256")))
      subject = Depwatcher::Httpd.new.tap { |s| s.client = client }
      
      subject.check.map(&.ref).should eq ["2.4.40", "2.4.41", "2.4.42", "2.4.43", "2.4.44", 
      "2.4.45", "2.4.46", "2.4.47", "2.4.48", "2.4.49", "2.4.50", "2.4.51", "2.4.52", "2.4.53", 
      "2.4.54", "2.4.55", "2.4.56", "2.4.57", "2.4.58", "2.4.59"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://api.github.com/repos/apache/httpd/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd_tags.json")))
      client.stub_get("https://archive.apache.org/dist/httpd-.*tar/.bz2.*tar\.bz2\.sha256", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/httpd.sha256")))
      subject = Depwatcher::Httpd.new.tap { |s| s.client = client }
      
      obj = subject.in("2.4.29")
      obj.ref.should eq "2.4.29"
      obj.url.should eq "https://dlcdn.apache.org/httpd/httpd-2.4.29.tar.bz2"
      obj.sha256.should eq "777753a5a25568a2a27428b2214980564bc1c38c1abf9ccc7630b639991f7f00"
    end
  end
end
