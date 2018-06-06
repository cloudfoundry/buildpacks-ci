#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'json'
require 'fileutils'
require 'digest'

def main
  app_name = ENV.fetch('APPLICATION_NAME')
  buildpack_url = ENV.fetch('BUILDPACK_URL')
  request_path = ENV.fetch('REQUEST_PATH')
  database_to_bind = ENV.fetch('DATABASE_TO_BIND')
  request_type = ENV.fetch('REQUEST_TYPE')

  system "./cf-space/login"

  bind_database(database_to_bind)

  push_app(buildpack_url, app_name)

  host = get_app_host(app_name, File.read("./cf-space/name").strip)

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
      java_jdk_dir = '/opt/java'
      java_jdk_tar_file = File.join(java_jdk_dir, 'openjdk-8-jdk.tar.gz')
      java_jdk_bin_dir = File.join(java_jdk_dir, 'bin')
      java_jdk_sha256 = '1315567082b55b3e1a62156d36c6f8adad152c32ab4a9eed7e72c1b24c381f9e'
      java_buildpack_java_sdk = "https://java-buildpack.cloudfoundry.org/openjdk-jdk/trusty/x86_64/openjdk-1.8.0_131.tar.gz"

      FileUtils.mkdir_p(java_jdk_dir)
      raise "Downloading openjdk-8-jdk failed." unless system("wget #{java_buildpack_java_sdk} -O #{java_jdk_tar_file}")

      downloaded_sha = Digest::SHA256.file(java_jdk_tar_file).hexdigest

      if java_jdk_sha256 != downloaded_sha
        raise "sha256 verification failed: expected #{java_jdk_sha256}, got #{downloaded_sha}"
      end

      raise "Untarring openjdk-8-jdk failed." unless system("tar xvf #{java_jdk_tar_file} -C #{java_jdk_dir}")

      ENV['JAVA_HOME'] = java_jdk_dir
      ENV['PATH'] = "#{ENV['PATH']}:#{java_jdk_bin_dir}"

      system "./gradlew assemble"
      FileUtils.mv("./build/libs/sample-app.jar", "./build/libs/spring-music-1.0.jar")
    end

    system "cf push #{app_name} -b #{buildpack_url} -t 180 --random-route"
  end
end

def get_app_host(app_name, space_name)
  spaces = JSON.parse(`cf curl '/v2/spaces' -X GET -H 'Content-Type: application/x-www-form-urlencoded' -d 'q=name:#{space_name}'`)
  space_guid = spaces['resources'].first['metadata']['guid']

  apps = JSON.parse(`cf curl '/v2/apps' -X GET -H 'Content-Type: application/x-www-form-urlencoded' -d 'q=name:#{app_name}&q=space_guid:#{space_guid}'`)
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
