require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/app_dynamics_agent.cr"

Spec2.describe Depwatcher::AppDynamicsAgent do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://download.appdynamics.com/download/downloadfilelatest/?format=json", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/appd_agent.json")))
  end

  describe "#check" do
    it "returns final releases sorted" do
      expect(subject.check.map(&.ref)).to eq ["4.3.3.100", "4.4.2.849", "4.4.2.850"]
    end
  end

  describe "#in" do
    it "returns final releases sorted" do
      obj = subject.in("4.4.2.849")
      expect(obj.ref).to eq "4.4.2.849"
      expect(obj.url).to eq "https://download.appdynamics.com/download/prox/download-file/php-tar/4.4.2.849/appdynamics-php-agent-x64-linux-4.4.2.849.tar.bz2"
      expect(obj.sha256).to eq "4b8baaf13a2c91c5a06f82e65d997b568f63c97c9e59901cb2f2d67800976c5f"
    end
  end
end
