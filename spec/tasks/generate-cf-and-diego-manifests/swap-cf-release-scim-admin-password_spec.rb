# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'script for filling cf manifest with correct admin password' do
  let(:cf_release_dir)       { File.join(File.dirname(__FILE__), 'cf-release') }
  let(:cf_tmp_manifest_file) { File.join(cf_release_dir, 'cf-tmp.yml') }
  let(:swap_script_file)     { File.join(File.dirname(__FILE__), '..', '..','..', 'tasks', 'generate-cf-and-diego-manifests', 'swap-cf-release-scim-admin-password.rb') }

  RSpec.shared_context "shared cf-release fixture setup" do
    before do
      @ci_cf_password = ENV['CI_CF_PASSWORD']
      ENV['CI_CF_PASSWORD'] = 'unique_password'

      FileUtils.cp(cf_manifest_file, cf_tmp_manifest_file)
    end

    after do
      ENV['CI_CF_PASSWORD'] = @ci_cf_password
      FileUtils.mv(cf_tmp_manifest_file, cf_manifest_file)
    end

    subject { `#{swap_script_file} #{cf_release_dir} #{cf_manifest_file}` }
  end

  context 'old style for uaa scim cf.yml manifest' do
    let(:cf_manifest_file) { File.join(cf_release_dir, 'cf-old-style.yml') }

    include_context "shared cf-release fixture setup"

    it 'swaps the scim admin user password with our specified password' do
      subject
      cf_manifest_contents = File.read(cf_manifest_file)
      expect(cf_manifest_contents).to eq(<<~CF_MANIFEST
                                            properties:
                                              uaa:
                                                scim:
                                                  users:
                                                  - admin|unique_password|scim.write,scim.read,openid,cloud_controller.admin,clients.read,clients.write,doppler.firehose,routing.router_groups.read,routing.router_groups.write
                                            CF_MANIFEST
                                        )
    end
  end

  context 'new style for uaa scim cf.yml manifest' do
    let(:cf_manifest_file) { File.join(cf_release_dir, 'cf-new-style.yml') }

    include_context "shared cf-release fixture setup"

    it 'swaps the scim admin user password with our specified password' do
      subject
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
end
