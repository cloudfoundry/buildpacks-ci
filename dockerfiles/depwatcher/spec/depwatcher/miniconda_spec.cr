require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/miniconda"

Spec2.describe Depwatcher::Miniconda do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://repo.continuum.io/miniconda/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/miniconda.html")))
    client.stub_get("https://repo.continuum.io/miniconda/Miniconda3-py37_4.8.2-Linux-x86_64.sh", nil, HTTP::Client::Response.new(200, "hello"))
    client.stub_get("https://repo.continuum.io/miniconda/Miniconda3-py38_4.8.2-Linux-x86_64.sh", nil, HTTP::Client::Response.new(200, "hello"))
  end

  describe "#check" do
    it "returns real linux releases for miniconda3-py37 sorted" do
      expect(subject.check("3.7").map(&.ref)).to eq ["4.8.2"]
    end
    it "returns real linux releases for miniconda3-py38 sorted" do
      expect(subject.check("3.8").map(&.ref)).to eq ["4.8.2"]
    end
  end

  describe "#in" do
    it "returns the release version, url, md5 for miniconda37" do
      obj = subject.in("3.7", "4.8.2")
      expect(obj.ref).to eq "4.8.2"
      expect(obj.url).to eq "https://repo.continuum.io/miniconda/Miniconda3-py37_4.8.2-Linux-x86_64.sh"
      expect(obj.md5).to eq "87e77f097f6ebb5127c77662dfc3165e"
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
    it "returns the release version, url, md5 for miniconda38" do
      obj = subject.in("3.8", "4.8.2")
      expect(obj.ref).to eq "4.8.2"
      expect(obj.url).to eq "https://repo.continuum.io/miniconda/Miniconda3-py38_4.8.2-Linux-x86_64.sh"
      expect(obj.md5).to eq "cbda751e713b5a95f187ae70b509403f"
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
   end
 end
end
