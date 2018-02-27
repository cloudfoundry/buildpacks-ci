require "json"
require "http/client"

module Depwatcher
  abstract class HTTPClient
    abstract def get(url : String) : HTTP::Client::Response
  end
  class HTTPClientImpl < HTTPClient
    def get(url : String) : String
      response = HTTP::Client.get(url)
      raise "Could not download data from #{url}: code #{response.status_code}" unless response.status_code == 200
      response.body
    end
  end

  class HTTPClientInsecure < HTTPClient
    def get(url : String) : String
      context = OpenSSL::SSL::Context::Client.insecure
      response = HTTP::Client.get(url, tls: context)
      raise "Could not download data from #{url}: code #{response.status_code}" unless response.status_code == 200
      response.body
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
