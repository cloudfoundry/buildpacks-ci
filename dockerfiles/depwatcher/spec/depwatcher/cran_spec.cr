require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/cran"

Spec2.describe Depwatcher::CRAN do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  before do
    client.stub_get("https://cran.r-project.org/web/packages/Rserve/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rserve.html")))
    client.stub_get("https://cran.r-project.org/web/packages/forecast/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/forecast.html")))
    client.stub_get("https://cran.r-project.org/web/packages/shiny/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/shiny.html")))
    client.stub_get("https://cran.r-project.org/web/packages/plumber/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/plumber.html")))
  end

  describe "#check" do
    it "returns the latest release in semver form" do
      expect(subject.check("Rserve").map(&.ref)).to eq [ "1.7.3" ]
      expect(subject.check("forecast").map(&.ref)).to eq [ "8.4" ]
      expect(subject.check("shiny").map(&.ref)).to eq [ "1.2.0" ]
      expect(subject.check("plumber").map(&.ref)).to eq [ "0.4.6" ]
    end
  end

  describe "#in" do
    it "returns the latest release download url" do
      obj = subject.in("Rserve", "1.7.3")
      expect(obj.ref).to eq "1.7.3"
      expect(obj.url).to eq "https://cran.r-project.org/src/contrib/Rserve_1.7-3.tar.gz"

      obj = subject.in("forecast", "8.4")
      expect(obj.ref).to eq "8.4"
      expect(obj.url).to eq "https://cran.r-project.org/src/contrib/forecast_8.4.tar.gz"

      obj = subject.in("shiny", "1.2.0")
      expect(obj.ref).to eq "1.2.0"
      expect(obj.url).to eq "https://cran.r-project.org/src/contrib/shiny_1.2.0.tar.gz"

      obj = subject.in("plumber", "0.4.6")
      expect(obj.ref).to eq "0.4.6"
      expect(obj.url).to eq "https://cran.r-project.org/src/contrib/plumber_0.4.6.tar.gz"
    end
  end
end
