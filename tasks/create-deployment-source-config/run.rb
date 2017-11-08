#!/usr/bin/env ruby

require 'yaml'

#See https://github.com/cloudfoundry/bosh-deployment-resource#dynamic-source-configuration

target_config = {}

Dir.chdir("bbl-state/#{ENV['ENV_NAME']}") do
  target_config = {
    "target"=> `bbl director-address`.strip,
    "client_secret"=> `bbl director-password`.strip,
    "client"=> `bbl director-username`.strip,
    "ca_cert"=> `bbl director-ca-cert`.strip
  }
end

File.write("deployment-source-config/source_file.yml", YAML.dump(target_config))
