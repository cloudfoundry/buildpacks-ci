#!/usr/bin/env ruby

require 'json'

admin_user = ENV['CI_CF_USERNAME']
admin_password = ENV['CI_CF_PASSWORD']
apps_domain = ENV['APPS_DOMAIN']
diego_docker_on = ENV['DIEGO_DOCKER_ON']

cats_config = {
  "admin_password" => admin_password,
  "admin_user" => admin_user,
  "api" => "api.#{apps_domain}",
  "apps_domain" => apps_domain,
  'async_service_operation_timeout' => 20,
  "backend" => "diego",
  'cf_push_timeout' => 10,
  'default_timeout' => 240,
  "enable_color" => true,
  "include_internet_dependent" => true,
  "include_routing" => false,
  "include_security_groups" => true,
  "include_services" => true,
  "include_ssh" => true,
  "include_sso" => false,
  "include_v3" => false,
  "keep_user_at_suite_end" => false,
  "skip_ssl_validation" => true,
  "use_existing_user" => false,
  "use_http" => false,
  "verbose" => false
}

if diego_docker_on == 'true'
  exit 1 unless system "cf api api.#{apps_domain} --skip-ssl-validation"
  exit 1 unless system "echo \"\" | cf login -u #{admin_user} -p #{admin_password}"
  exit 1 unless system "cf enable-feature-flag diego_docker"
  cats_config['include_docker'] = true
end

puts "Writing CATS config to integration-config/integration_config.json"

File.write('integration-config/integration_config.json', JSON.pretty_generate(cats_config))
