#!/usr/bin/env ruby

require 'yaml'

#See https://github.com/cloudfoundry/bosh-deployment-resource#dynamic-source-configuration

target_config = {}

Dir.chdir("bbl-state/#{ENV['ENV_NAME']}") do
  target_config = {
    "target"=> `bbl director-address`.strip,
    "client"=> `bbl director-username`.strip,
    "client_secret"=> `bbl director-password`.strip,
    "ca_cert"=> `bbl director-ca-cert`.strip,
    "jumpbox_url"=> `bbl jumpbox-address`.strip + ':22',
    "jumpbox_ssh_key"=>YAML.load(open('vars/jumpbox-vars-store.yml').read).dig('jumpbox_ssh','private_key')
  }
end

File.write("deployment-source-config/source_file.yml", YAML.dump(target_config))
