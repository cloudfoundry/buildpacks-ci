require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/app_dynamics_agent.cr"

Spec2.describe Depwatcher::AppDynamicsAgent do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://download.run.pivotal.io/appdynamics-php/index.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/appd_agent.yml")))

    client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-2.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-1"))
    client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-1.1.1-3.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-2"))
    client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-2.1.1-1.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-3"))
    client.stub_get("https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2", nil, HTTP::Client::Response.new(200,  "some-content-4"))
  end

  describe "#check" do
    it "returns final releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["1.1.1-2", "1.1.1-3", "2.1.1-1", "3.1.1-14"]
    end
  end

  describe "#in" do
    it "returns final releases sorted" do
      obj = subject.in("3.1.1-14")
      expect(obj.ref).to eq "3.1.1-14"
      expect(obj.url).to eq "https://download.run.pivotal.io/appdynamics-php/appdynamics-3.1.1-14.tar.bz2"
      expect(obj.sha256).to eq OpenSSL::Digest.new("sha256").update("some-content-4").hexdigest
    end
  end
end
