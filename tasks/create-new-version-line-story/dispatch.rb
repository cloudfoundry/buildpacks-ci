#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

def send_dispatch(name, version, jsonData, token)
  jsonStr = JSON.generate(jsonData)
  uri = URI.parse("https://api.github.com/repos/cloudfoundry/buildpacks-github-config/dispatches")
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "token #{token}"
  request.body = "{
                \"event_type\": \"new-version-line\",
                \"client_payload\":{
                  \"Name\": \"#{name}\",
                  \"Version\": \"#{version}\",
                  \"DependencyJSON\": #{jsonStr}
                }
              }"
  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  response.value()
end
