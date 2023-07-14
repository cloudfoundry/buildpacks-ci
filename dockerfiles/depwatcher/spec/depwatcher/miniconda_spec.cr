require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/miniconda"

Spec2.describe Depwatcher::Miniconda do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://repo.anaconda.com/miniconda/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/miniconda.html")))
    client.stub_get("https://repo.anaconda.com/miniconda/Miniconda3-py39_23.1.0-1-Linux-x86_64.sh", nil, HTTP::Client::Response.new(200, "hello"))
    client.stub_get("https://repo.anaconda.com/miniconda/Miniconda3-py38_23.1.0-1-Linux-x86_64.sh", nil, HTTP::Client::Response.new(200, "hello"))
  end

  describe "#check" do
    it "returns real linux releases for miniconda3-py39 sorted" do
      expect(subject.check("3.9").map(&.ref)).to eq ["22.11.1", "23.1.0",
      "23.3.1", "23.5.0", "23.5.1", "23.5.2"]
    end
    it "returns real linux releases for miniconda3-py38 sorted" do
      expect(subject.check("3.8").map(&.ref)).to eq ["22.11.1", "23.1.0",
      "23.3.1", "23.5.0", "23.5.1", "23.5.2"]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256 for miniconda39" do
      obj = subject.in("3.9", "23.1.0")
      expect(obj.ref).to eq "23.1.0"
      expect(obj.url).to eq "https://repo.anaconda.com/miniconda/Miniconda3-py39_23.1.0-1-Linux-x86_64.sh"
      expect(obj.sha256).to eq "5dc619babc1d19d6688617966251a38d245cb93d69066ccde9a013e1ebb5bf18"
    end
    it "returns the release version, url, sha256 for miniconda38" do
      obj = subject.in("3.8", "23.1.0")
      expect(obj.ref).to eq "23.1.0"
      expect(obj.url).to eq "https://repo.anaconda.com/miniconda/Miniconda3-py38_23.1.0-1-Linux-x86_64.sh"
      expect(obj.sha256).to eq "640b7dceee6fad10cb7e7b54667b2945c4d6f57625d062b2b0952b7f3a908ab7"
   end
  end
end
