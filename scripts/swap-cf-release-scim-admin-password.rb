#!/usr/bin/env ruby

cf_release_dir = ARGV[0]
cf_manifest_file = ARGV[1]

Dir.chdir(cf_release_dir) do
  cf_manifest_contents = File.read(cf_manifest_file)

  if cf_manifest_contents.match /admin\|admin\|scim\.write,scim\.read/
    cf_manifest_contents.gsub!('admin|admin', 'admin|' + ENV['CI_CF_PASSWORD'])
  else
    to_swap = <<-SCIM
    scim:
      external_groups: null
      groups: null
      userids_enabled: true
      users:
      - groups:
        - scim.write
        - scim.read
        - openid
        - cloud_controller.admin
        - clients.read
        - clients.write
        - doppler.firehose
        - routing.router_groups.read
        - routing.router_groups.write
        name: admin
        password: admin
    SCIM

    swapped = <<-SCIM
    scim:
      external_groups: null
      groups: null
      userids_enabled: true
      users:
      - groups:
        - scim.write
        - scim.read
        - openid
        - cloud_controller.admin
        - clients.read
        - clients.write
        - doppler.firehose
        - routing.router_groups.read
        - routing.router_groups.write
        name: admin
        password: #{ENV['CI_CF_PASSWORD']}
    SCIM

    cf_manifest_contents.gsub!(to_swap, swapped)
  end

  File.write(cf_manifest_file, cf_manifest_contents)
end
