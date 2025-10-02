require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/cran"

describe Depwatcher::CRAN do
  describe "#check" do
    it "returns the latest release in semver form" do
      client = HTTPClientMock.new
      subject = Depwatcher::CRAN.new.tap { |s| s.client = client }
      client.stub_get("https://cran.r-project.org/web/packages/Rserve/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rserve.html")))
      client.stub_get("https://cran.r-project.org/web/packages/forecast/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/forecast.html")))
      client.stub_get("https://cran.r-project.org/web/packages/shiny/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/shiny.html")))
      client.stub_get("https://cran.r-project.org/web/packages/plumber/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/plumber.html")))
      
      subject.check("Rserve").map(&.ref).should eq [ "1.7.3" ]
      subject.check("forecast").map(&.ref).should eq [ "8.4" ]
      subject.check("shiny").map(&.ref).should eq [ "1.2.0" ]
      subject.check("plumber").map(&.ref).should eq [ "0.4.6" ]
    end
  end

  describe "#in" do
    it "returns the latest release download url" do
      client = HTTPClientMock.new
      subject = Depwatcher::CRAN.new.tap { |s| s.client = client }
      client.stub_get("https://cran.r-project.org/web/packages/Rserve/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/rserve.html")))
      client.stub_get("https://cran.r-project.org/web/packages/forecast/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/forecast.html")))
      client.stub_get("https://cran.r-project.org/web/packages/shiny/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/shiny.html")))
      client.stub_get("https://cran.r-project.org/web/packages/plumber/index.html", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/plumber.html")))
      
      obj = subject.in("Rserve", "1.7.3")
      obj.ref.should eq "1.7.3"
      obj.url.should eq "https://cran.r-project.org/src/contrib/Rserve_1.7-3.tar.gz"

      obj = subject.in("forecast", "8.4")
      obj.ref.should eq "8.4"
      obj.url.should eq "https://cran.r-project.org/src/contrib/forecast_8.4.tar.gz"

      obj = subject.in("shiny", "1.2.0")
      obj.ref.should eq "1.2.0"
      obj.url.should eq "https://cran.r-project.org/src/contrib/shiny_1.2.0.tar.gz"

      obj = subject.in("plumber", "0.4.6")
      obj.ref.should eq "0.4.6"
      obj.url.should eq "https://cran.r-project.org/src/contrib/plumber_0.4.6.tar.gz"
    end
  end
end
