require "spec2"
require "../../src/depwatcher/node_lts"

Spec2.describe Depwatcher::NodeLTS do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }

  describe "#check" do
    before do
      client.stub_get("https://nodejs.org/en/about/releases/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_lts_info_page.html"))
      )

      client.stub_get("https://nodejs.org/dist/",
        nil,
        HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/node_dist.html"))
      )
    end
    it "returns the right number of releases" do
      expect(subject.check.size).to eq 26
    end

    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["16.0.0", "16.1.0", "16.2.0", "16.3.0", "16.4.0", "16.4.1", "16.4.2", "16.5.0", "16.6.0", "16.6.1", "16.6.2", "16.7.0", "16.8.0", "16.9.0", "16.9.1", "16.10.0", "16.11.0", "16.11.1", "16.12.0", "16.13.0", "16.13.1", "16.13.2", "16.14.0", "16.14.1", "16.14.2", "16.15.0"]
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
