require "json"
require "http/client"

module Depwatcher
  abstract class HTTPClient
    abstract def get(url : String) : HTTP::Client::Response
  end

  class HTTPClientImpl < HTTPClient
    def get(url : String) : HTTP::Client::Response
      response = HTTP::Client.get(url)
      if response.status_code == 301 || response.status_code == 302
        get(response.headers["location"])
      elsif response.status_code == 200
        response
      else
        raise "Could not download data from #{url}: code #{response.status_code}"
      end
    end
  end

  class HTTPClientInsecure < HTTPClient
    def get(url : String) : HTTP::Client::Response
      context = OpenSSL::SSL::Context::Client.insecure
      response = HTTP::Client.get(url, tls: context)
      if response.status_code == 301 || response.status_code == 302
        get(response.headers["location"])
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
  end
end
