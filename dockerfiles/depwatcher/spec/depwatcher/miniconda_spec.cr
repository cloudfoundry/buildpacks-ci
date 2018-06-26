require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/miniconda"

Spec2.describe Depwatcher::Miniconda do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://repo.continuum.io/miniconda/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/miniconda.html")))
  end

  describe "#check" do
    it "returns real linux releases for miniconda2 sorted" do
      expect(subject.check("2").map(&.ref)).to eq [
        "3.18.3", "3.18.9", "3.19.0", "4.0.5", "4.1.11", "4.2.11",
        "4.2.12", "4.3.11", "4.3.14", "4.3.21", "4.3.27",
        "4.3.27.1", "4.3.30", "4.3.31", "4.4.10", "4.5.1", "4.5.4"
      ]
    end
    it "returns real linux releases for miniconda3 sorted" do
      expect(subject.check("3").map(&.ref)).to eq [
        "2.2.2", "3.0.0", "3.0.4", "3.0.5", "3.3.0", "3.4.2", "3.5.2", "3.5.5", "3.6.0",
        "3.7.0", "3.7.3", "3.8.3", "3.9.1", "3.10.1", "3.16.0", "3.18.3",
        "3.18.9", "3.19.0", "4.0.5", "4.1.11", "4.2.11",
        "4.2.12", "4.3.11", "4.3.14", "4.3.21", "4.3.27", "4.3.27.1",
        "4.3.30", "4.3.31", "4.4.10", "4.5.1", "4.5.4"
      ]
    end

  end

  describe "#in" do
    it "returns the release version, url, md5 for miniconda2" do
      obj = subject.in("2", "4.5.4")
      expect(obj.ref).to eq "4.5.4"
      expect(obj.url).to eq "https://repo.continuum.io/miniconda/Miniconda2-4.5.4-Linux-x86_64.sh"
      expect(obj.md5).to eq "8a1c02f6941d8778f8afad7328265cf5"
    end
    it "returns the release version, url, md5 for miniconda3" do
     obj = subject.in("3", "4.5.4")
     expect(obj.ref).to eq "4.5.4"
     expect(obj.url).to eq "https://repo.continuum.io/miniconda/Miniconda3-4.5.4-Linux-x86_64.sh"
     expect(obj.md5).to eq "a946ea1d0c4a642ddf0c3a26a18bb16d"
   end
 end
end
