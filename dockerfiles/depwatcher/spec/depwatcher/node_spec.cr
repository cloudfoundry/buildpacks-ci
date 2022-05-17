require "spec2"
require "../../src/depwatcher/node"

Spec2.describe Depwatcher::Node do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }

  describe "#check" do
    before do
      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
    end
    it "returns the right number of releases" do
      expect(subject.check.size).to eq 120
    end

    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["12.0.0", "12.1.0", "12.2.0", "12.3.0", "12.3.1", "12.4.0", "12.5.0", "12.6.0", "12.7.0", "12.8.0", "12.8.1", "12.9.0", 
      "12.9.1", "12.10.0", "12.11.0", "12.11.1", "12.12.0", "12.13.0", "12.13.1", "12.14.0", "12.14.1", "12.15.0", "12.16.0", "12.16.1", "12.16.2", "12.16.3", "12.17.0", 
      "12.18.0", "12.18.1", "12.18.2", "12.18.3", "12.18.4", "12.19.0", "12.19.1", "12.20.0", "12.20.1", "12.20.2", "12.21.0", "12.22.0", "12.22.1", "12.22.2", "12.22.3", 
      "12.22.4", "12.22.5", "12.22.6", "12.22.7", "12.22.8", "12.22.9", "12.22.10", "12.22.11", "12.22.12", "14.0.0", "14.1.0", "14.2.0", "14.3.0", "14.4.0", "14.5.0", 
      "14.6.0", "14.7.0", "14.8.0", "14.9.0", "14.10.0", "14.10.1", "14.11.0", "14.12.0", "14.13.0", "14.13.1", "14.14.0", "14.15.0", "14.15.1", "14.15.2", "14.15.3", "14.15.4", 
      "14.15.5", "14.16.0", "14.16.1", "14.17.0", "14.17.1", "14.17.2", "14.17.3", "14.17.4", "14.17.5", "14.17.6", "14.18.0", "14.18.1", "14.18.2", "14.18.3", "14.19.0", "14.19.1", 
      "14.19.2", "14.19.3", "16.0.0", "16.1.0", "16.2.0", "16.3.0", "16.4.0", "16.4.1", "16.4.2", "16.5.0", "16.6.0", "16.6.1", "16.6.2", "16.7.0", "16.8.0", "16.9.0", "16.9.1", 
      "16.10.0", "16.11.0", "16.11.1", "16.12.0", "16.13.0", "16.13.1", "16.13.2", "16.14.0", "16.14.1", "16.14.2", "16.15.0", "18.0.0", "18.1.0", "18.2.0"]
    end

    it "returns only non-LTS versions" do
      expect(subject.check.map(&.ref).select { |v|
        semver = Semver.new(v)
        semver.major % 2 != 0
      }).to eq [] of String
    end
  end

  describe "#in" do
    let(version) { "6.1.0" }
    before do
      client.stub_get("https://nodejs.org/dist/v#{version}/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_v6.1.0.html"))
      )
      client.stub_get("https://nodejs.org/dist/v#{version}/SHASUMS256.txt",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_shasum256.txt"))
      )
    end
    it "returns real releases sorted" do
      obj = subject.in("6.1.0")
      expect(obj.ref).to eq "6.1.0"
      expect(obj.url).to eq "https://nodejs.org/dist/v6.1.0/node-v6.1.0.tar.gz"
      expect(obj.sha256).to eq "9e67ef0b8611e16e6e311eccf0489a50fe76ceebeea3023ef4f51be647ae4bc3"
    end
  end
end
