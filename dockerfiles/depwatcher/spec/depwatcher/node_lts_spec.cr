require "spec2"
require "../../src/depwatcher/node_lts"

Spec2.describe Depwatcher::NodeLTS do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }

  describe "#check" do
    before do
      client.stub_get("https://raw.githubusercontent.com/nodejs/Release/main/schedule.json",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_lts_releases.json"))
      )

      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
    end
    it "returns the right number of releases" do
      expect(subject.check.size).to eq 3
    end

    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq  ["20.0.0", "20.8.0", "20.9.0"]
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
