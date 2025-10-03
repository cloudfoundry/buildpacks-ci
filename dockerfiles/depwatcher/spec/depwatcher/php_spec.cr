require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/php"
require "../../src/depwatcher/semver"

describe Depwatcher::Php do
  describe "#check" do
    it "returns filtered releases sorted for PHP 8.0" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      results = subject.check("8.0")
      results.should_not be_empty
      results.first.ref.should match(/^8\.0\./)
      
      refs = results.map(&.ref)
      sorted_refs = refs.sort_by { |r| Semver.new(r) }
      refs.should eq(sorted_refs)
    end
    
    it "returns filtered releases sorted for PHP 7.4" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      results = subject.check("7.4")
      results.should_not be_empty
      results.first.ref.should match(/^7\.4\./)
      
      refs = results.map(&.ref)
      sorted_refs = refs.sort_by { |r| Semver.new(r) }
      refs.should eq(sorted_refs)
    end

    it "returns all release versions from HTML when phpwatch unavailable" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      results = subject.check("8.1")
      
      php81_versions = results.select { |r| r.ref.starts_with?("8.1.") }
      php81_versions.should_not be_empty
      php81_refs = php81_versions.map(&.ref)
      php81_refs.includes?("8.1.0").should be_true
      php81_refs.includes?("8.1.1").should be_true
    end
    
    it "handles versions that were never released" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      results = subject.check("7.4")
      refs = results.map(&.ref)
      refs.includes?("7.4.17").should be_false
      
      results_80 = subject.check("8.0")
      refs_80 = results_80.map(&.ref)
      refs_80.includes?("8.0.4").should be_false
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256 for a valid version" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      client.stub_get("https://php.net/distributions/php-8.0.1.tar.gz", nil, HTTP::Client::Response.new(200, "mock-tarball-content-for-sha256"))
      
      obj = subject.in("8.0.1")
      obj.ref.should eq "8.0.1"
      obj.url.should eq "https://php.net/distributions/php-8.0.1.tar.gz"
      obj.sha256.should_not be_empty
    end
    
    it "returns the release version, url, sha256 for older versions" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      client.stub_get("https://php.net/distributions/php-7.4.0.tar.gz", nil, HTTP::Client::Response.new(200, "mock-tarball-content-for-sha256"))
      
      obj = subject.in("7.4.0")
      obj.ref.should eq "7.4.0"
      obj.url.should eq "https://php.net/distributions/php-7.4.0.tar.gz"
      obj.sha256.should_not be_empty
    end
  end
  
  describe "#old_versions" do
    it "extracts PHP versions from HTML releases page" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      results = subject.old_versions()
      results.should_not be_empty
      
      refs = results.map(&.ref)
      refs.includes?("8.1.1").should be_true
      refs.includes?("8.0.14").should be_true
      refs.includes?("7.4.26").should be_true
      refs.includes?("7.3.33").should be_true
      
      refs.each do |ref|
        ref.should match(/^[78]\.\d+\.\d+$/)
      end
    end
  end
  
  describe "#get_latest_supported_version" do
    it "returns a version string in major.minor format" do
      client = HTTPClientMock.new
      subject = Depwatcher::Php.new.tap { |s| s.client = client }
      client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
      
      version = subject.get_latest_supported_version()
      version.should match(/^\d+\.\d+$/)
      version.split('.').size.should eq(2)
    end
  end
end
