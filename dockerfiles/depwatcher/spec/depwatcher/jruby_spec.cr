require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/jruby"

describe Depwatcher::JRuby do
  describe "#check" do
    it "returns releases sorted" do
      client = HTTPClientMock.new
      client.stub_get("https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.2.0.0/jruby-dist-9.2.0.0-src.zip.sha256", nil, HTTP::Client::Response.new(200, "3d59bde1639c69965664ee46a07be230141ee8e99d2e7f43b574a6a8298c887c\n"))
      client.stub_get("https://www.jruby.org/download", nil, HTTP::Client::Response.new(200, File.read(File.join(__DIR__,"..", "fixtures", "jruby.html"))))
      subject = Depwatcher::JRuby.new.tap { |s| s.client = client }
      
      subject.check().map(&.ref).should eq ["9.1.17.0", "9.2.0.0"]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256" do
      client = HTTPClientMock.new
      client.stub_get("https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.2.0.0/jruby-dist-9.2.0.0-src.zip.sha256", nil, HTTP::Client::Response.new(200, "3d59bde1639c69965664ee46a07be230141ee8e99d2e7f43b574a6a8298c887c\n"))
      client.stub_get("https://www.jruby.org/download", nil, HTTP::Client::Response.new(200, File.read(File.join(__DIR__,"..", "fixtures", "jruby.html"))))
      subject = Depwatcher::JRuby.new.tap { |s| s.client = client }
      
      obj = subject.in("9.2.0.0")
      obj.ref.should eq "9.2.0.0"
      obj.url.should eq "https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.2.0.0/jruby-dist-9.2.0.0-src.zip"
      obj.sha256.should eq "3d59bde1639c69965664ee46a07be230141ee8e99d2e7f43b574a6a8298c887c"
    end
  end
end
