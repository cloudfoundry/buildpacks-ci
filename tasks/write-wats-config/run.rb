#!/usr/bin/env ruby

require 'json'

admin_user = ENV.fetch('CI_CF_USERNAME')
admin_password = ENV.fetch('CI_CF_PASSWORD')
apps_domain = ENV.fetch('APPS_DOMAIN')
diego_docker_on = ENV.fetch('DIEGO_DOCKER_ON')

wats_config = {
  "api" => "api.#{apps_domain}",
  "admin_user" => admin_user,
  "admin_password" => admin_password,
  "apps_domain" => apps_domain,

  "credhub_mode" => "assisted",

  "secure_address" => "10.0.0.6", #wtf
  "num_windows_cells" => 1,#verify

  "skip_ssl_validation" => true,

  "consul_mutual_tls" => false, #?
  "http_healthcheck" => true, #?
  "test_task" => true, #?
  "skip_ssh" => false, #?
  "isolation_segment_name" => "", #?
  "stack" => "windows2012R2"

  # ,
  # "credhub_mode" => "assisted",
  # "include_credhub" => true
}

if diego_docker_on == 'true'
  exit 1 unless system "cf api api.#{apps_domain} --skip-ssl-validation"
  exit 1 unless system "echo \"\" | cf login -u #{admin_user} -p #{admin_password}"
end

puts "Writing WATs config to integration-config/integration_config.json"

File.write('integration-config/integration_config.json', JSON.pretty_generate(wats_config))
