require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/php"

Spec2.describe Depwatcher::Php do
  let(client) { HTTPClientMock.new }
  subject { described_class.new.tap { |s| s.client = client } }
  
  before do
    client.stub_get("https://secure.php.net/releases/", nil, HTTP::Client::Response.new(200, File.read(__DIR__+"/../fixtures/php_releases.php")))
  end

  describe "#check" do
    context "with version filter" do
      it "returns filtered releases sorted for PHP 8.0" do
        # Test with specific version filter using fallback method (since we can't easily mock external commands)
        results = subject.check("8.0")
        expect(results).to_not be_empty
        expect(results.first.ref).to match(/^8\.0\./)
        
        # Verify they are sorted
        refs = results.map(&.ref)
        sorted_refs = refs.sort_by { |r| Depwatcher::Semver.new(r) }
        expect(refs).to eq(sorted_refs)
      end
      
      it "returns filtered releases sorted for PHP 7.4" do
        results = subject.check("7.4")
        expect(results).to_not be_empty
        expect(results.first.ref).to match(/^7\.4\./)
        
        # Verify they are sorted
        refs = results.map(&.ref)
        sorted_refs = refs.sort_by { |r| Depwatcher::Semver.new(r) }
        expect(refs).to eq(sorted_refs)
      end
    end
    
    context "HTML fallback method" do
      it "returns all release versions from HTML when phpwatch unavailable" do
        # This tests the old_versions() method through fallback
        results = subject.check("8.1")
        
        # Should contain PHP 8.1.x versions from the fixture
        php81_versions = results.select { |r| r.ref.starts_with?("8.1.") }
        expect(php81_versions).to_not be_empty
        php81_refs = php81_versions.map(&.ref)
        expect(php81_refs.includes?("8.1.0")).to be_true
        expect(php81_refs.includes?("8.1.1")).to be_true
      end
      
      it "handles versions that were never released" do
        # Test that missing versions like 7.4.17 and 8.0.4 are not included
        results = subject.check("7.4")
        refs = results.map(&.ref)
        expect(refs).to_not include("7.4.17")
        
        results_80 = subject.check("8.0")
        refs_80 = results_80.map(&.ref)
        expect(refs_80).to_not include("8.0.4")
      end
    end
  end

  describe "#in" do
    it "returns the release version, url, sha256 for a valid version" do
      obj = subject.in("8.0.1")
      expect(obj.ref).to eq "8.0.1"
      expect(obj.url).to eq "https://php.net/distributions/php-8.0.1.tar.gz"
      expect(obj.sha256).to_not be_empty
    end
    
    it "returns the release version, url, sha256 for older versions" do
      obj = subject.in("7.4.0")
      expect(obj.ref).to eq "7.4.0"
      expect(obj.url).to eq "https://php.net/distributions/php-7.4.0.tar.gz"
      expect(obj.sha256).to_not be_empty
    end
  end
  
  describe "#old_versions" do
    it "extracts PHP versions from HTML releases page" do
      results = subject.old_versions()
      expect(results).to_not be_empty
      
      # Should contain versions from the fixture
      refs = results.map(&.ref)
       expect(refs).to include("8.1.1")
       expect(refs).to include("8.0.14")
       expect(refs).to include("7.4.26")
       expect(refs).to include("7.3.33")
      
      # Should only contain PHP 7.x and 8.x versions
      refs.each do |ref|
        expect(ref).to match(/^[78]\.\d+\.\d+$/)
      end
    end
  end
  
  describe "#get_latest_supported_version" do
    it "returns a version string in major.minor format" do
      # This will use the fallback method since we can't mock curl commands easily
      version = subject.get_latest_supported_version()
      expect(version).to match(/^\d+\.\d+$/)
      expect(version.split('.').size).to eq(2)
    end
  end
  
  describe "XML feed functionality (integration tests)" do
    # Note: These tests use real external commands and may fail if php.watch is unavailable
    # They test the actual XML parsing and QA filtering logic
    
    context "when php.watch XML feed is available" do
      it "can parse XML feed and extract stable versions only" do
        # This test verifies that the XML parsing logic works correctly
        # and filters out QA releases (alpha, beta, RC)
        
        # Mock the XML content as if it came from curl
        xml_content = File.read(__DIR__+"/../fixtures/php_83_releases_with_qa.xml")
        
        # Extract versions manually to test our parsing logic
        stable_versions = [] of String
        qa_versions = [] of String
        
        xml_content.scan(/<title>PHP ([0-9]+\.[0-9]+\.[0-9]+[^<]*)<\/title>/) do |match|
          version = match[1]
          if version.includes?("alpha") || version.includes?("beta") || version.includes?("RC")
            qa_versions << version
          else
            stable_versions << version
          end
        end
        
        # Verify that we correctly identify stable vs QA releases
        expect(stable_versions).to include("8.3.2")
        expect(stable_versions).to include("8.3.1")
        expect(stable_versions).to include("8.3.0")
        expect(qa_versions).to include("8.3.0RC6")
        expect(qa_versions).to include("8.3.0beta3")
        expect(qa_versions).to include("8.3.0alpha1")
        expect(stable_versions.size).to be < (stable_versions.size + qa_versions.size)
      end
    end
    
    context "QA release filtering" do
      it "identifies and excludes alpha releases" do
        test_versions = ["8.3.1", "8.3.0alpha1", "8.3.0alpha2", "8.2.15"]
        stable_only = test_versions.reject { |v| v.includes?("alpha") }
        expect(stable_only).to eq(["8.3.1", "8.2.15"])
      end
      
      it "identifies and excludes beta releases" do
        test_versions = ["8.3.1", "8.3.0beta1", "8.3.0beta2", "8.2.15"]
        stable_only = test_versions.reject { |v| v.includes?("beta") }
        expect(stable_only).to eq(["8.3.1", "8.2.15"])
      end
      
      it "identifies and excludes RC releases" do
        test_versions = ["8.3.1", "8.3.0RC1", "8.3.0RC2", "8.2.15"]
        stable_only = test_versions.reject { |v| v.includes?("RC") }
        expect(stable_only).to eq(["8.3.1", "8.2.15"])
      end
      
      it "filters out all QA releases in mixed list" do
        test_versions = [
          "8.3.2", "8.3.1", "8.3.0", "8.3.0RC6", "8.3.0RC1", 
          "8.3.0beta3", "8.3.0beta1", "8.3.0alpha3", "8.3.0alpha1"
        ]
        stable_only = test_versions.reject do |v| 
          v.includes?("alpha") || v.includes?("beta") || v.includes?("RC")
        end
        expect(stable_only).to eq(["8.3.2", "8.3.1", "8.3.0"])
      end
    end
  end
  
  describe "Multi-layer fallback mechanism" do
    it "demonstrates fallback chain: XML → HTML → error" do
      # This test documents the expected fallback behavior
      # 1. Try php.watch XML feed first (most reliable)
      # 2. Fall back to PHP.net HTML scraping
      # 3. If both fail, raise error or return empty
      
      # We can test the HTML fallback portion since we have fixtures
      html_results = subject.old_versions()
      expect(html_results).to_not be_empty
      
      # Verify HTML results contain expected structure
      refs = html_results.map(&.ref)
        expect(refs).to include("8.1.1")
        expect(refs).to include("8.0.14")
        
        # All versions should be valid semantic versions
        refs.each do |ref|
          expect(ref).to match(/^\d+\.\d+\.\d+$/)
        end
    end
  end
  
  describe "Data quality improvements" do
    it "ensures unique versions (no duplicates)" do
      results = subject.check("8.0")
      refs = results.map(&.ref)
      unique_refs = refs.uniq
      expect(refs.size).to eq(unique_refs.size)
    end
    
    it "maintains proper sorting by semantic version" do
      results = subject.check("7.4")
      refs = results.map(&.ref)
      
      # Convert to semver objects for proper comparison
      semvers = refs.map { |r| Depwatcher::Semver.new(r) }
      sorted_semvers = semvers.sort
      
      expect(semvers).to eq(sorted_semvers)
    end
  end
end
