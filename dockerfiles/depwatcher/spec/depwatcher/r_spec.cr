require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/r"

Spec2.describe Depwatcher::R do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://cran.r-project.org/src/base/R-4/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rlang.html")))
    client.stub_get("https://cran.r-project.org/src/base/R-3/R-3.3.2.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq [
        "4.0.0", "4.0.1", "4.0.2", "4.0.3", "4.0.4", "4.0.5", "4.1.0"
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("3.3.2")
      expect(obj.ref).to eq "3.3.2"
      expect(obj.url).to eq "https://cran.r-project.org/src/base/R-3/R-3.3.2.tar.gz"
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
