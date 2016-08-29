# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'script for filling cf manifest with correct admin password' do
  let(:cf_release_dir)   { File.join(File.dirname(__FILE__), 'cf-release') }
  let(:cf_manifest_file) { File.join(cf_release_dir, 'cf.yml') }

  before do
    @ci_cf_password = ENV['CI_CF_PASSWORD']
    ENV['CI_CF_PASSWORD'] = 'unique_password'

    FileUtils.cp(cf_manifest_file, File.join(cf_release_dir, 'cf_old.yml'))

    swap_script_file = File.join(File.dirname(__FILE__), '..', '..', '..', 'scripts', 'swap-cf-release-scim-admin-password.rb')
    `#{swap_script_file} #{cf_release_dir} #{cf_manifest_file}`
  end

  after do
    ENV['CI_CF_PASSWORD'] = @ci_cf_password
    FileUtils.mv(File.join(cf_release_dir, 'cf_old.yml'), cf_manifest_file)
  end


  it 'swaps the scim admin user password with our specified password' do
    cf_manifest_contents = File.read(cf_manifest_file)
    expect(cf_manifest_contents).to eq(<<~CF_MANIFEST
                                          properties:
                                            uaa:
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
                                                  password: unique_password
                                          CF_MANIFEST
                                      )
  end
end
