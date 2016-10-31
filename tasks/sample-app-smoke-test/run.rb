#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'json'

def delete_space(space)
  puts `cf delete-space #{space} -f`
end

def target_cf(cf_api, cf_username, cf_password, cf_organization, cf_login_space, cf_app_space)
  puts `cf login -a #{cf_api} -u #{cf_username} -p #{cf_password} -o #{cf_organization} -s #{cf_login_space}`

  puts `cf create-space #{cf_app_space}`

  puts `cf target -o #{cf_organization} -s #{cf_app_space}`
end

def push_app(buildpack_url, app_name)
  Dir.chdir('sample-app') do
    if app_name == 'spring-music'
      `apt-get update && apt-get install -y openjdk-7-jdk`
      puts `./gradlew assemble`
    end

    puts `cf push -b #{buildpack_url} --random-route`
  end
end

def get_app_route_host(app_name)
  apps = JSON.parse(`cf curl '/v2/apps' -X GET -H 'Content-Type: application/x-www-form-urlencoded' -d 'q=name:#{app_name}'`)
  routes_url = apps['resources'].first['entity']['routes_url']

  routes = JSON.parse(`cf curl #{routes_url}`)
  routes['resources'].first['entity']['host']
end

def get_app_response(host, domain, path, type)
  request_uri = URI("https://#{host}.#{domain}#{path}")

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
      puts `cf create-service cleardb spark mysql`
    when 'pgsql'
      puts `cf create-service elephantsql turtle pgsql`
  end
end

cf_api = ENV['CF_API']
cf_username = ENV['CF_USERNAME']
cf_password = ENV['CF_PASSWORD']
cf_organization = ENV['CF_ORGANIZATION']
cf_domain = ENV['CF_DOMAIN']
cf_login_space = ENV['CF_LOGIN_SPACE']
app_name = ENV['APPLICATION_NAME']
buildpack_url = ENV['BUILDPACK_URL']
request_path = ENV['REQUEST_PATH']
database_to_bind = ENV['DATABASE_TO_BIND']
request_type = ENV['REQUEST_TYPE']
cf_app_space = "sample-app-#{Random.rand(100000)}"

env_vars = %w(CF_API CF_USERNAME CF_PASSWORD CF_ORGANIZATION CF_DOMAIN CF_LOGIN_SPACE APPLICATION_NAME BUILDPACK_URL REQUEST_PATH DATABASE_TO_BIND REQUEST_TYPE)

env_vars.each do |var|
  if ENV[var].nil?
    puts "#{var} is not set. Exiting..."
    exit 1
  end
end

target_cf(cf_api, cf_username, cf_password, cf_organization, cf_login_space, cf_app_space)

begin
  bind_database(database_to_bind)

  push_app(buildpack_url, app_name)

  app_route_host = get_app_route_host(app_name)

  response = get_app_response(app_route_host, cf_domain, request_path, request_type)
ensure
  delete_space(cf_app_space)
end

if response.code == "200"
  puts 'Got HTTP response 200. App push successful'
else
  puts "Got HTTP response #{response.code}. App push unsuccessful"
  exit 1
end
