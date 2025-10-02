require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/node"

describe Depwatcher::Node do
  describe "#check" do
    it "returns the right number of releases" do
      client = HTTPClientMock.new
      subject = Depwatcher::Node.new.tap { |s| s.client = client }
      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
      
      subject.check.size.should eq 14
    end

    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::Node.new.tap { |s| s.client = client }
      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
      
      subject.check.map(&.ref).should eq ["14.0.0", "14.5.0", "16.0.0", "16.5.0", "16.9.0", "18.0.0", "18.5.0", "18.9.0", "20.0.0", "20.8.0", "20.9.0", "22.0.0", "22.1.0", "22.2.0"]
    end

    it "returns only non-LTS versions" do
      client = HTTPClientMock.new
      subject = Depwatcher::Node.new.tap { |s| s.client = client }
      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
      
      subject.check.map(&.ref).select { |v|
        semver = Semver.new(v)
        semver.major % 2 != 0
      }.should eq [] of String
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::Node.new.tap { |s| s.client = client }
      version = "6.1.0"
      client.stub_get("https://nodejs.org/dist/v#{version}/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_v6.1.0.html"))
      )
      client.stub_get("https://nodejs.org/dist/v#{version}/SHASUMS256.txt",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_shasum256.txt"))
      )
      
      obj = subject.in("6.1.0")
      obj.ref.should eq "6.1.0"
      obj.url.should eq "https://nodejs.org/dist/v6.1.0/node-v6.1.0.tar.gz"
      obj.sha256.should eq "9e67ef0b8611e16e6e311eccf0489a50fe76ceebeea3023ef4f51be647ae4bc3"
    end
  end
end
