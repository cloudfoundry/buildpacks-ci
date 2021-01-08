require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/php"

Spec2.describe Depwatcher::Php do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://secure.php.net/downloads.php", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_downloads.php")))
    client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
  end

  describe "#check" do
    it "returns all releases sorted" do
      expect(subject.check().map(&.ref)).to eq [
        "7.0.0", "7.0.1", "7.0.2", "7.0.3", "7.0.4", "7.0.5", "7.0.6", "7.0.7", "7.0.8", "7.0.9",
        "7.0.10", "7.0.11", "7.0.12", "7.0.13", "7.0.14", "7.0.15", "7.0.16", "7.0.17", "7.0.18",
        "7.0.19", "7.0.20", "7.0.21", "7.0.22", "7.0.23", "7.0.24", "7.0.25", "7.0.26", "7.0.27",
        "7.0.28", "7.0.29", "7.0.30", "7.0.31", "7.0.32", "7.0.33", "7.1.0", "7.1.1", "7.1.2",
        "7.1.3", "7.1.4", "7.1.5", "7.1.6", "7.1.7", "7.1.8", "7.1.9", "7.1.10", "7.1.11", "7.1.12",
        "7.1.13", "7.1.14", "7.1.15", "7.1.16", "7.1.17", "7.1.18", "7.1.19", "7.1.20", "7.1.21",
        "7.1.22", "7.1.23", "7.1.24", "7.1.25", "7.1.26", "7.1.27", "7.1.28", "7.1.29", "7.1.30",
        "7.1.31", "7.1.32", "7.1.33", "7.2.0", "7.2.1", "7.2.2", "7.2.3", "7.2.4", "7.2.5", "7.2.6",
        "7.2.7", "7.2.8", "7.2.9", "7.2.10", "7.2.11", "7.2.12", "7.2.13", "7.2.14", "7.2.15",
        "7.2.16", "7.2.17", "7.2.18", "7.2.19", "7.2.20", "7.2.21", "7.2.22", "7.2.23", "7.2.24",
        "7.2.25", "7.2.26", "7.2.27", "7.2.28", "7.2.29", "7.2.30", "7.2.31", "7.2.32", "7.2.33",
        "7.2.34", "7.3.0", "7.3.1", "7.3.2", "7.3.3", "7.3.4", "7.3.5", "7.3.6", "7.3.7", "7.3.8",
        "7.3.9", "7.3.10", "7.3.11", "7.3.12", "7.3.13", "7.3.14", "7.3.15", "7.3.16", "7.3.17",
        "7.3.18", "7.3.19", "7.3.20", "7.3.21", "7.3.22", "7.3.23", "7.3.24", "7.3.25", "7.3.26",
        "7.4.0", "7.4.1", "7.4.2", "7.4.3", "7.4.4", "7.4.5", "7.4.6", "7.4.7", "7.4.8", "7.4.9",
        "7.4.10", "7.4.11", "7.4.12", "7.4.13", "7.4.14", "8.0.0", "8.0.1"]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256 when php patch is latest" do
      obj = subject.in("8.0.1")
      expect(obj.ref).to eq "8.0.1"
      expect(obj.url).to eq "https://php.net/distributions/php-8.0.1.tar.gz"
      expect(obj.sha256).to eq "f1fee0429aa2cce6bc5df5d7e65386e266b0aab8a5fad7882d10eb833d2f5376"
    end
    it "returns the release version, url, sha256 when php patch is not latest" do
      obj = subject.in("7.0.0")
      expect(obj.ref).to eq "7.0.0"
      expect(obj.url).to eq "https://php.net/distributions/php-7.0.0.tar.gz"
      expect(obj.sha256).to eq "d6ae7b4a2e5c43a9945a97e83b6b3adfb7d0df0b91ef78b647a6dffefaa9c71b"
    end
  end
end
