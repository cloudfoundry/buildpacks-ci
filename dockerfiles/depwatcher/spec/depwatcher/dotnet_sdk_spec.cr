require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/dotnet_sdk"

Spec2.describe Depwatcher::DotnetSdk do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }

  before do
    client.stub_get(
      "https://api.github.com/repos/dotnet/cli/tags?per_page=1000",
      nil,
      HTTP::Client::Response.new(
        200,
        File.read(__DIR__ + "/../fixtures/dotnet_tags.json")
      )
    )
    client.stub_get(
      "https://github.com/dotnet/cli/archive/2a1f1c6d30c73c1bce0b557ebbdfba1008e9ae63.tar.gz",
      nil,
      HTTP::Client::Response.new( 200, "hello")
    )
    client.stub_get(
      "https://github.com/dotnet/cli/archive/99151dfa08364242d93c861568abaf044e134d8c.tar.gz",
      nil,
      HTTP::Client::Response.new( 200, "hello")
    )
  end

  describe "#check" do
    it "returns dotnet sdk release versions sorted" do
      regex = "^(v1\\.\\d+\\.\\d+|v2\\.\\d+\\.\\d+\\+dependencies|v3\\.\\d+.\\d+-preview\\d+-\\d+)$"
      checked_deps = subject.check(regex)
      expect(checked_deps.map(&.ref)).to eq [
      "1.1.0", "1.1.3", "1.1.4", "1.1.5", "1.1.6", "1.1.7", "1.1.8",
       "1.1.9", "1.1.10", "1.1.11", "1.1.12", "1.1.13", "1.1.14",
       "2.1.301", "2.1.402", "2.1.403", "2.1.500", "2.1.503", "2.1.504",
       "2.1.505", "2.1.506", "2.1.507", "2.1.602", "2.1.603", "2.2.100",
       "2.2.102", "2.2.104", "2.2.105", "2.2.106", "2.2.107", "2.2.202",
       "2.2.203", "2.2.204", "3.0.100-preview4", "3.0.100-preview6"
      ]
    end
  end

  describe "#in" do
    it "returns a dotnet sdk release" do
      obj = subject.in("2.1.301", ".*\\+dependencies")
      if obj 
        expect(obj.ref).to eq "2.1.301"
        expect(obj.url).to eq "https://github.com/dotnet/cli"
        expect(obj.git_commit_sha).to eq "2a1f1c6d30c73c1bce0b557ebbdfba1008e9ae63"
        expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
      else
        expect(obj.nil?).to be_false
      end
    end
  end

  describe "#in for 3.0.X preview" do
      it "returns the latest dotnet sdk release" do
        regex = "^(v1\\.\\d+\\.\\d+|v2\\.\\d+\\.\\d+\\+dependencies|v3\\.\\d+.\\d+-preview\\d+-\\d+)$"
        obj = subject.in("3.0.100-preview6", regex)
        if obj
          expect(obj.ref).to eq "3.0.100-preview6"
          expect(obj.url).to eq "https://github.com/dotnet/cli"
          expect(obj.git_commit_sha).to eq "99151dfa08364242d93c861568abaf044e134d8c"
          expect(obj.sha256).to eq "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        else
          expect(obj.nil?).to be_false
        end
      end
    end
end
