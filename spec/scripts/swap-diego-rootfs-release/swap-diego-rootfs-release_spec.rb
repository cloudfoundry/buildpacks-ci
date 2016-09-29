# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'yaml'

describe 'script for filling diego manifest with correct rootfs release' do
  let(:diego_release_dir)       { File.join(File.dirname(__FILE__), 'diego') }
  let(:diego_manifest_file) { File.join(diego_release_dir, 'diego.yml') }
  let(:diego_tmp_manifest_file) { File.join(diego_release_dir, 'diego-tmp.yml') }
  let(:swap_script_file)     { File.join(File.dirname(__FILE__), '..', '..', '..', 'scripts', 'swap-diego-rootfs-release.rb') }

  before do
    @rootfs_release = ENV['ROOTFS_RELEASE']
    ENV['ROOTFS_RELEASE'] = 'a_rootfs_bosh_release'

    FileUtils.cp(diego_manifest_file, diego_tmp_manifest_file)
  end

  after do
    ENV['ROOTFS_RELEASE'] = @rootfs_release
    FileUtils.mv(diego_tmp_manifest_file, diego_manifest_file)
  end

  subject { `#{swap_script_file} #{diego_release_dir} #{diego_manifest_file}` }

  it 'swaps the rootfs bosh release' do
      subject
      diego_manifest_contents = File.read(diego_manifest_file)
      expect(diego_manifest_contents).to eq(<<~DIEGO
                                                 templates:
                                                 - name: nsync
                                                   release: cf
                                                 - name: cflinuxfs2-rootfs-setup
                                                   release: a_rootfs_bosh_release
                                                 - name: route_emitter
                                                   release: diego

                                               releases:
                                               - name: diego
                                                 version: latest
                                               - name: a_rootfs_bosh_release
                                                 version: latest
                                               - name: etcd
                                                 version: latest
                                               - name: garden-linux
                                                 version: latest
                                               - name: cf
                                                 version: latest
                                               DIEGO
                                        )
  end
end
