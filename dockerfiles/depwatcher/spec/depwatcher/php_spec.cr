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
        "5.6.36", "7.0.0", "7.0.1", "7.0.2", "7.0.3", "7.0.4", "7.0.5", "7.0.6",
        "7.0.7", "7.0.8", "7.0.9", "7.0.10", "7.0.11", "7.0.12", "7.0.13", "7.0.14",
        "7.0.15", "7.0.16", "7.0.17", "7.0.18", "7.0.19", "7.0.20", "7.0.21", "7.0.22",
        "7.0.23", "7.0.24", "7.0.25", "7.0.26", "7.0.27", "7.0.28", "7.0.29", "7.0.30",
        "7.0.30", "7.1.0", "7.1.1", "7.1.2", "7.1.3", "7.1.4", "7.1.5", "7.1.6", "7.1.7",
        "7.1.8", "7.1.9", "7.1.10", "7.1.11", "7.1.12", "7.1.13", "7.1.14", "7.1.15",
        "7.1.16", "7.1.17", "7.1.18", "7.1.19", "7.1.19", "7.2.0", "7.2.1", "7.2.2",
        "7.2.3", "7.2.4", "7.2.5", "7.2.6", "7.2.7", "7.2.7",
      ]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256 when php patch is latest" do
      obj = subject.in("7.1.19")
      expect(obj.ref).to eq "7.1.19"
      expect(obj.url).to eq "https://php.net/distributions/php-7.1.19.tar.gz"
      expect(obj.sha256).to eq "e1ae477b72bed02cdcb04f0157b8f8767bd4f6030416ae06408b4f6d85ee66a1"
    end
    it "returns the release version, url, sha256 when php patch is not latest" do
      obj = subject.in("7.0.30")
      expect(obj.ref).to eq "7.0.30"
      expect(obj.url).to eq "https://php.net/distributions/php-7.0.30.tar.gz"
      expect(obj.sha256).to eq "54e7615205123b940b996300bf99c707c2317b6b78388061a204b23ab3388a26"
    end
 end
end
