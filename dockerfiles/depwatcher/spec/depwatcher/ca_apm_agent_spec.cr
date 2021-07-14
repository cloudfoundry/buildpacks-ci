require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/ca_apm_agent"

Spec2.describe Depwatcher::CaApmAgent do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/apm_agents.html")))
    client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["10.6.0", "10.7.0"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("10.6.0")
      expect(obj.ref).to eq "10.6.0"
      expect(obj.url).to eq "https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz"
      expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
