#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'json'

def main
  app_name = ENV.fetch('APPLICATION_NAME')
  buildpack_url = ENV.fetch('BUILDPACK_URL')
  request_path = ENV.fetch('REQUEST_PATH')
  database_to_bind = ENV.fetch('DATABASE_TO_BIND')
  request_type = ENV.fetch('REQUEST_TYPE')

  system "./cf-space/login"

  bind_database(database_to_bind)

  push_app(buildpack_url, app_name)

  host = get_app_host(app_name)

  response = get_app_response(host, request_path, request_type)

  if response.code == "200"
    puts 'Got HTTP response 200. App push successful'
  else
    puts "Got HTTP response #{response.code}. App push unsuccessful"
    exit 1
  end
end

def push_app(buildpack_url, app_name)
  Dir.chdir('sample-app') do
    if app_name == 'spring-music'
      `apt-get update && apt-get install -y openjdk-7-jdk`
      system "./gradlew assemble"
    end

    system "cf push #{app_name} -b #{buildpack_url} -t 180 --random-route"
  end
end

def get_app_host(app_name)
  apps = JSON.parse(`cf curl '/v2/apps' -X GET -H 'Content-Type: application/x-www-form-urlencoded' -d 'q=name:#{app_name}'`)
  routes_url = apps['resources'].first['entity']['routes_url']

  routes = JSON.parse(`cf curl #{routes_url}`)
  name = routes['resources'].first['entity']['host']
  domain_url = routes['resources'].first['entity']['domain_url']

  domains = JSON.parse(`cf curl #{domain_url}`)
  domain = domains['entity']['name']

  "#{name}.#{domain}"
end

def get_app_response(host, path, type)
  request_uri = URI("https://#{host}#{path}")

  Net::HTTP.start(request_uri.host, request_uri.port, :use_ssl => true) do |http|
    req = case type
            when 'DELETE' then Net::HTTP::Delete.new(request_uri)
            when 'GET' then Net::HTTP::Get.new(request_uri)
            else raise "Invalid request type #{type}"
          end
    http.request(req)
  end
end

def bind_database(database)
  case database
    when 'mysql'
      system "cf create-service cleardb spark mysql"
    when 'pgsql'
      system "cf create-service elephantsql turtle pgsql"
  end
end

main
