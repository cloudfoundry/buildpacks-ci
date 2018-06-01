require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/r"

Spec2.describe Depwatcher::R do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://svn.r-project.org/R/tags/", HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rlang.html")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "3.2.4", "3.2.5", "3.3.0", "3.3.1", "3.3.2", "3.3.3", "3.4.0", "3.4.1",
        "3.4.2", "3.4.3"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("3.3.2")
      expect(obj.ref).to eq "3.3.2"
      expect(obj.url).to eq "https://cran.cnr.berkeley.edu/src/base/R-3/R-3.3.2.tar.gz"
    end
  end
end
