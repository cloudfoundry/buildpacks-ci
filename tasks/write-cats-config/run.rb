#!/usr/bin/env ruby

require 'json'

admin_user = ENV.fetch('CI_CF_USERNAME')
admin_password = ENV.fetch('CI_CF_PASSWORD')
apps_domain = ENV.fetch('APPS_DOMAIN')
diego_docker_on = ENV.fetch('DIEGO_DOCKER_ON')

cats_config = {
  "admin_password" => admin_password,
  "admin_user" => admin_user,
  "api" => "api.#{apps_domain}",
  "apps_domain" => apps_domain,
  "async_service_operation_timeout" => 1200,
  "backend" => "diego",
  "cf_push_timeout" => 600,
  "default_timeout" => 240,
  "include_apps" => true,
  "include_app" => true,
  "include_backend_compatibility" => true,
  "include_detect" => true,
  "include_docker" => false,
  "include_internet_dependent" => true,
  "include_persistent_app" => false,
  "include_route_services" => false,
  "include_routing" => false,
  "include_security_groups" => true,
  "include_services" => true,
  "include_ssh" => true,
  "include_sso" => true,
  "include_tasks" => true,
  "include_v3" => false,
  "include_zipkin" => false,
  "skip_ssl_validation" => true,
  "timeout_scale" => 1,
  "use_http" => true,
  "verbose" => false
}

if diego_docker_on == 'true'
  exit 1 unless system "cf api api.#{apps_domain} --skip-ssl-validation"
  exit 1 unless system "echo \"\" | cf login -u #{admin_user} -p #{admin_password}"
end

puts "Writing CATS config to integration-config/integration_config.json"

File.write('integration-config/integration_config.json', JSON.pretty_generate(cats_config))
