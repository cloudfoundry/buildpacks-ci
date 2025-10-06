require "spec"
require "./httpclient_mock"
require "../../src/depwatcher/ruby"

describe Depwatcher::Ruby do
  describe "#check" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::Ruby.new.tap { |s| s.client = client }
      client.stub_get("https://api.github.com/repos/ruby/ruby/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_ruby.json")))
      client.stub_get("https://cache.ruby-lang.org/pub/ruby/index.txt", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_index.txt")))
      client.stub_get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_github_releases.yml")))
      
      subject.check.map(&.ref).should eq [
        "2.2.2", "2.2.3", "2.2.4", "2.2.5", "2.2.6", "2.2.7",
        "2.2.8", "2.2.9", "2.3.0", "2.3.1", "2.3.2", "2.3.3",
        "2.3.4", "2.3.5", "2.3.6", "2.4.0", "2.4.1", "2.4.2", "2.4.3", "2.5.0",
      ]
    end
  end

  describe "#in" do
    it "returns real releases sorted" do
      client = HTTPClientMock.new
      subject = Depwatcher::Ruby.new.tap { |s| s.client = client }
      client.stub_get("https://api.github.com/repos/ruby/ruby/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_ruby.json")))
      client.stub_get("https://cache.ruby-lang.org/pub/ruby/index.txt", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_index.txt")))
      client.stub_get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_github_releases.yml")))
      
      obj = subject.in("2.5.0")
      if obj
        obj.ref.should eq "2.5.0"
        obj.url.should eq "https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.0.tar.gz"
        obj.sha256.should eq "46e6f3630f1888eb653b15fa811d77b5b1df6fd7a3af436b343cfe4f4503f2ab"
      else
        false.should be_true
      end
    end

    it "returns real releases when 2.5.7" do
      client = HTTPClientMock.new
      subject = Depwatcher::Ruby.new.tap { |s| s.client = client }
      client.stub_get("https://api.github.com/repos/ruby/ruby/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_ruby.json")))
      client.stub_get("https://cache.ruby-lang.org/pub/ruby/index.txt", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_index.txt")))
      client.stub_get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_github_releases.yml")))
      
      obj = subject.in("2.5.7")
      if obj
        obj.ref.should eq "2.5.7"
        obj.url.should eq "https://cache.ruby-lang.org/pub/ruby/2.5/ruby-2.5.7.tar.gz"
        obj.sha256.should eq "0b2d0d5e3451b6ab454f81b1bfca007407c0548dea403f1eba2e429da4add6d4"
      else
        false.should be_true
      end
    end

    it "returns real releases when 3.0.0" do
      client = HTTPClientMock.new
      subject = Depwatcher::Ruby.new.tap { |s| s.client = client }
      client.stub_get("https://api.github.com/repos/ruby/ruby/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_ruby.json")))
      client.stub_get("https://cache.ruby-lang.org/pub/ruby/index.txt", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_index.txt")))
      client.stub_get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_github_releases.yml")))
      
      obj = subject.in("3.0.0")
      if obj
        obj.ref.should eq "3.0.0"
        obj.url.should eq "https://cache.ruby-lang.org/pub/ruby/3.0/ruby-3.0.0.tar.gz"
        obj.sha256.should eq "a13ed141a1c18eb967aac1e33f4d6ad5f21be1ac543c344e0d6feeee54af8e28"
      else
        false.should be_true
      end
    end

    it "returns real releases when 2.2.10" do
      client = HTTPClientMock.new
      subject = Depwatcher::Ruby.new.tap { |s| s.client = client }
      client.stub_get("https://api.github.com/repos/ruby/ruby/tags?per_page=1000", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/github_ruby.json")))
      client.stub_get("https://cache.ruby-lang.org/pub/ruby/index.txt", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_index.txt")))
      client.stub_get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml", nil, HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/ruby_github_releases.yml")))
      
      obj = subject.in("2.2.10")
      if obj
        obj.ref.should eq "2.2.10"
        obj.url.should eq "https://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.10.tar.gz"
        obj.sha256.should eq "cd51019eb9d9c786d6cb178c37f6812d8a41d6914a1edaf0050c051c75d7c358"
      else
        false.should be_true
      end
    end
  end
end
