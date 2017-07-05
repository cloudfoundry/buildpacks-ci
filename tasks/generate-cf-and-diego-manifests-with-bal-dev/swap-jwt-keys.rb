#!/usr/bin/env ruby

require 'tmpdir'
require 'yaml'

cf_release_dir = ARGV[0]
cf_manifest_file = ARGV[1]

Dir.chdir(cf_release_dir) do
  cf_manifest_contents = File.read(cf_manifest_file)

  temp_key_dir = Dir.mktmpdir
  jwt_private_key_file = File.join(temp_key_dir, 'jwt_signing.key')
  jwt_public_key_file = File.join(temp_key_dir, 'jwt_signing.pub')

  raise "Generating JWT key failed." unless system("openssl genrsa -aes256 -out #{jwt_private_key_file} -passout pass:password 1024")
  raise "Removing JWT key password failed." unless system("openssl rsa -in #{jwt_private_key_file} -out #{jwt_private_key_file} -passin pass:password")
  raise "Deriving JWT public key failed." unless system("openssl rsa -in #{jwt_private_key_file} -pubout > #{jwt_public_key_file}")

  jwt_private_key = File.read(jwt_private_key_file)
  jwt_public_key = File.read(jwt_public_key_file)

  cf_manifest_yaml = YAML.load(cf_manifest_contents)
  cf_manifest_yaml['properties']['uaa']['jwt']['signing_key'] = jwt_private_key
  cf_manifest_yaml['properties']['uaa']['jwt']['verification_key'] = jwt_public_key

  File.write(cf_manifest_file, cf_manifest_yaml.to_yaml)

  FileUtils.rm_rf(temp_key_dir)
end
