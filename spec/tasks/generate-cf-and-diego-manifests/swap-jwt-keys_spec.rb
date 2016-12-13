# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'script for swapping out the default jwt keys in CF manifest' do
  let(:cf_release_dir)       { File.join(File.dirname(__FILE__), 'cf-release') }
  let(:cf_tmp_manifest_file) { File.join(cf_release_dir, 'cf-tmp.yml') }
  let(:swap_script_file)     { File.join(File.dirname(__FILE__), '..', '..','..', 'tasks', 'generate-cf-and-diego-manifests', 'swap-jwt-keys.rb') }
  let(:cf_manifest_file) { File.join(cf_release_dir, 'cf-with-jwt-signing-key.yml') }

  before { FileUtils.cp(cf_manifest_file, cf_tmp_manifest_file) }

  after { FileUtils.mv(cf_tmp_manifest_file, cf_manifest_file) }

  subject { `#{swap_script_file} #{cf_release_dir} #{cf_manifest_file}` }

  it 'replaces the default jwt signing key with a generated SSH key' do
    subject
    cf_manifest_contents = File.read(cf_manifest_file)
    cf_manifest_yaml = YAML.load(cf_manifest_contents)
    jwt = cf_manifest_yaml['properties']['uaa']['jwt']

    expect(jwt['signing_key']).to match(/^-----BEGIN RSA PRIVATE KEY-----\nMIIC.*\n-----END RSA PRIVATE KEY-----$/m)
    expect(jwt['signing_key']).to_not include("DEFAULT_GENERATED_JWT_SIGNING_PRIVATE_KEY_CONTENTS")

    expect(jwt['verification_key']).to match(/^-----BEGIN PUBLIC KEY-----\nMIGf.*\n-----END PUBLIC KEY-----$/m)
    expect(jwt['verification_key']).to_not include("DEFAULT_GENERATED_JWT_VERIFICATION_PUBLIC_KEY_CONTENTS")
  end
end
