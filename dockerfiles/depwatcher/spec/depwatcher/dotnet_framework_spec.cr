require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/dotnet_framework.cr"

Spec2.describe Depwatcher::DotnetFramework do
  let(client) {HTTPClientMock.new}
  subject {described_class.new.tap {|s| s.client = client}}
  before do
    client.stub_get("https://api.github.com/repos/cloudfoundry/public-buildpacks-ci-robots/contents/binary-builds-new/dotnet-framework", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/dotnet_framework.json")))
  end

  describe "#check" do
    it "returns real releases sorted" do
      expect(subject.check().map(&.ref)).to eq ["1.0.11", "1.1.8", "2.1.0-rc1-26423-06"]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      obj = subject.in("1.0.11")
      expect(obj.ref).to eq "1.0.11"
    end
  end
end
