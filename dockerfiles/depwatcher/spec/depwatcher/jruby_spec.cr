require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/jruby"

Spec2.describe Depwatcher::JRuby do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://s3.amazonaws.com/jruby.org/downloads/9.2.0.0/jruby-src-9.2.0.0.tar.gz.sha256", nil, HTTP::Client::Response.new(200, "3d59bde1639c69965664ee46a07be230141ee8e99d2e7f43b574a6a8298c887c\n"))
    client.stub_get("http://jruby.org/download", nil, HTTP::Client::Response.new(200, File.read(File.join(__DIR__,"..", "fixtures", "jruby.html"))))
  end

  describe "#check" do
    it "returns releases sorted" do
      expect(subject.check().map(&.ref)).to eq ["9.1.17.0", "9.2.0.0"]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256" do
     obj = subject.in("9.2.0.0")
     expect(obj.ref).to eq "9.2.0.0"
     expect(obj.url).to eq "https://s3.amazonaws.com/jruby.org/downloads/9.2.0.0/jruby-src-9.2.0.0.tar.gz"
     expect(obj.sha256).to eq "3d59bde1639c69965664ee46a07be230141ee8e99d2e7f43b574a6a8298c887c"
   end
 end
end
