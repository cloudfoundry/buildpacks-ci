require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/r"

Spec2.describe Depwatcher::R do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://svn.r-project.org/R/tags/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rlang.html")))
    client.stub_get("https://cran.cnr.berkeley.edu/src/base/R-3/R-3.3.2.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
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
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
