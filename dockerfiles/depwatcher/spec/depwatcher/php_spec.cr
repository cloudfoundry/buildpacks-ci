require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/php"

Spec2.describe Depwatcher::Php do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://secure.php.net/downloads.php", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_downloads.php")))
  end

  describe "#check" do
    it "returns releases sorted" do
      expect(subject.check().map(&.ref)).to eq [
        "5.6.36", "7.0.30", "7.1.19", "7.2.7",
      ]
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256" do
      obj = subject.in("7.1.19")
      expect(obj.ref).to eq "7.1.19"
      expect(obj.url).to eq "https://php.net/distributions/php-7.1.19.tar.gz"
      expect(obj.sha256).to eq "e1ae477b72bed02cdcb04f0157b8f8767bd4f6030416ae06408b4f6d85ee66a1"
    end
 end
end
