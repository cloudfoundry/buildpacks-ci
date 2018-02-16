#!/usr/bin/env ruby

require 'yaml'

#See https://github.com/cloudfoundry/bosh-deployment-resource#dynamic-source-configuration

target_config = {}

`wget https://github.com/cloudfoundry/bosh-bootloader/releases/download/v5.11.5/bbl-v5.11.5_linux_x86-64`
`chmod 755 bbl-v5.11.5_linux_x86-64`
BBL = "#{Dir.pwd}/bbl-v5.11.5_linux_x86-64"

Dir.chdir("bbl-state/#{ENV['ENV_NAME']}") do
  target_config = {
    "deployment"=> "cf",
    "target"=> `#{BBL} director-address`.strip,
    "client"=> `#{BBL} director-username`.strip,
    "client_secret"=> `#{BBL} director-password`.strip,
    "ca_cert"=> `#{BBL} director-ca-cert`.strip,
    "jumpbox_url"=> `#{BBL} jumpbox-address`.strip + ':22',
    "jumpbox_ssh_key"=>YAML.load(open('vars/jumpbox-vars-store.yml').read).dig('jumpbox_ssh','private_key')
  }
end

File.write("deployment-source-config/source_file.yml", YAML.dump(target_config))
