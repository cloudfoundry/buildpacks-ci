#!/usr/bin/env ruby

require 'json'

admin_password = File.read("cf-admin-password/password")
apps_domain = ENV.fetch('APPS_DOMAIN')
diego_docker_on = ENV.fetch('DIEGO_DOCKER_ON')
credhub_mode = ENV.fetch('CREDHUB_MODE')
credhub_client = ENV.fetch('CREDHUB_CLIENT')
credhub_secret = ENV.fetch('CREDHUB_CLIENT_SECRET')
windows_stack = ENV.fetch('WINDOWS_STACK')
stacks = ENV.fetch('STACKS','')

cats_config = {
  "admin_password" => admin_password,
  "admin_user" => "admin",
  "api" => "api.#{apps_domain}",
  "apps_domain" => apps_domain,
  "credhub_mode" => credhub_mode,
  "credhub_client" => credhub_client,
  "credhub_secret" => credhub_secret,
  "async_service_operation_timeout" => 1200,
  "backend" => "diego",
  "cf_push_timeout" => 600,
  "default_timeout" => 240,
  "include_apps" => true,
  "include_app" => true,
  "include_backend_compatibility" => true,
  "include_detect" => true,
  "include_docker" => false,
  "include_credhub" => true,
  "include_internet_dependent" => true,
  "include_persistent_app" => false,
  "include_route_services" => false,
  "include_routing" => false,
  "include_security_groups" => false,
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

if stacks != ''
  cats_config.merge!({
    "stacks" => stacks.split(' '),
  })
end

if windows_stack != '' && windows_stack != nil
  cats_config.merge!({ "include_windows" => true,
    "num_windows_cells" => 1,
    "windows_stack" => windows_stack,
  })
end

if diego_docker_on == 'true'
  exit 1 unless system "cf api api.#{apps_domain} --skip-ssl-validation"
  exit 1 unless system "echo \"\" | cf login -u #{admin_user} -p #{admin_password}"
end

puts "Writing CATS config to integration-config/integration_config.json"

File.write('integration-config/integration_config.json', JSON.pretty_generate(cats_config))
