require "json"
require "http/client"

module Depwatcher
  abstract class HTTPClient
    abstract def get(url : String) : HTTP::Client::Response
    def injectOauthAuthorizationTokenIntoHeader(headers : HTTP::Headers? = nil)
      # read token from env variable e.g. github authorization token
      apiKey = ENV["OAUTH_AUTHORIZATION_TOKEN"]?
      if headers == nil
        headers = HTTP::Headers.new
      end
      if apiKey != nil
        headers.not_nil!["Authorization"] = "token " + apiKey.not_nil!
      end
      return headers
    end
  end

  class HTTPClientImpl < HTTPClient
    def get(url : String, headers : HTTP::Headers? = nil) : HTTP::Client::Response
      headers = injectOauthAuthorizationTokenIntoHeader(headers)
      response = HTTP::Client.get(url, headers)
      if response.status_code == 301 || response.status_code == 302
        get(response.headers["location"], headers)
      elsif response.status_code == 200
        response
      else
        raise "Could not download data from #{url}: code #{response.status_code}"
      end
    end
  end

  class HTTPClientInsecure < HTTPClient
    def get(url : String, headers : HTTP::Headers? = nil) : HTTP::Client::Response
      headers = injectOauthAuthorizationTokenIntoHeader(headers)
      context = OpenSSL::SSL::Context::Client.insecure
      response = HTTP::Client.get(url, headers: headers, tls: context)
      if response.status_code == 301 || response.status_code == 302
        get(response.headers["location"], headers)
      elsif response.status_code == 200
        response
      else
        raise "Could not download data from #{url}: code #{response.status_code}"
      end
    end
  end

  class Base
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(@ref : String)
      end
    end

    property client : HTTPClient
    def initialize(@client = HTTPClientImpl.new)
    end

    def get_sha256(url : String)
      data = client.get(url).body
      hash = OpenSSL::Digest.new("SHA256")
      hash.update(data)
      return hash.hexdigest
    end
  end
end
