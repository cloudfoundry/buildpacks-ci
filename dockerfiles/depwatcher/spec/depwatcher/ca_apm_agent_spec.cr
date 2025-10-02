require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/ca_apm_agent"

describe Depwatcher::CaApmAgent do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::CaApmAgent.new.tap { |s| s.client = client }
      client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/apm_agents.html")))
      client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
      
      subject.check.map(&.ref).should eq ["10.6.0", "10.7.0"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::CaApmAgent.new.tap { |s| s.client = client }
      client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/apm_agents.html")))
      client.stub_get("https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz", nil, HTTP::Client::Response.new(200, "hello"))
      
      obj = subject.in("10.6.0")
      obj.ref.should eq "10.6.0"
      obj.url.should eq "https://packages.broadcom.com/artifactory/apm-agents/CA-APM-PHPAgent-10.6.0_linux.tar.gz"
      obj.sha256.should eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end
  end
end
