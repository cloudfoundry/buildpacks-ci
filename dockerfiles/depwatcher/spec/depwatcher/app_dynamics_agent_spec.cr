require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/app_dynamics_agent.cr"

describe Depwatcher::AppDynamicsAgent do
  describe "#check" do
    it "returns final releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::AppDynamicsAgent.new.tap { |s| s.client = client }
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/index.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/appd_agent.yml")))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-1"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-3.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-2"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-2.1.1-1.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-3"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-4"))
      
      subject.check.map(&.ref).should eq ["1.1.1-2", "1.1.1-3", "2.1.1-1", "3.1.1-14"]
    end
  end

  describe "#in" do
    it "returns final releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::AppDynamicsAgent.new.tap { |s| s.client = client }
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/index.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/appd_agent.yml")))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-1"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-3.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-2"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-2.1.1-1.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-3"))
      client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-4"))
      
      obj = subject.in("3.1.1-14")
      obj.ref.should eq "3.1.1-14"
      obj.url.should eq "https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2"
      obj.sha256.should eq OpenSSL::Digest.new("sha256").update("some-content-4").final.hexstring
    end
  end
end
