# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/bosh-lite-manager'

require 'tmpdir'
require 'fileutils'
require 'yaml'

describe BoshLiteManager do
  let(:iaas) { 'aws' }
  let(:deployment_id) { "edge-17.buildpacks.ci" }
  let(:deployment_dir) { File.join(Dir.mktmpdir, deployment_id) }
  let(:bosh_lite_user) { 'admin_user' }
  let(:bosh_lite_password) { 'this_is_a_password' }
  let(:bosh_lite_deployment_name) { 'edge-17' }
  let(:bosh_lite_url) { 'https://edge-17.buildpacks.ci.example.com' }
  let(:bosh_director_user) { 'admin_director' }
  let(:bosh_director_password) { 'also_a_password' }
  let(:bosh_director_target) { 'bosh.example.com' }
  let(:bosh_private_key) { 'APRIVATESSHKEY' }

  subject { described_class.new(iaas: iaas,
                                deployment_dir: deployment_dir,
                                deployment_id: deployment_id,
                                bosh_lite_user: bosh_lite_user,
                                bosh_lite_password: bosh_lite_password,
                                bosh_lite_deployment_name: bosh_lite_deployment_name,
                                bosh_lite_url: bosh_lite_url,
                                bosh_director_user: bosh_director_user,
                                bosh_director_password: bosh_director_password,
                                bosh_director_target: bosh_director_target,
                                bosh_private_key: bosh_private_key
                               )
          }

  before do
    allow(subject).to receive(:run_or_exit)
    FileUtils.mkdir_p(deployment_dir)
  end

  after { FileUtils.rm_rf(deployment_dir) }

  describe '#recreate' do
    let(:bosh_lite_running) { true }

    before do
      allow(subject).to receive(:install_ssh_key)
      allow(subject).to receive(:delete_aws_instances)
      allow(subject).to receive(:deploy_aws_bosh_lite)
      allow(subject).to receive(:target_bosh_director)
      allow(subject).to receive(:delete_bosh_deployment)
      allow(subject).to receive(:deploy_bosh_lite)
      allow(subject).to receive(:bosh_lite_running?).and_return(bosh_lite_running)
      allow(subject).to receive(:update_admin_password)
      allow(subject).to receive(:cleanup_deployment_manifests)
      allow(GitClient).to receive(:add_everything)
      allow(GitClient).to receive(:safe_commit)
      allow(subject).to receive(:puts)
    end

    context 'iaas is aws' do
      it 'deploys bosh-lite to aws and makes the git commits' do
        expect(subject).to receive(:install_ssh_key).with("#{deployment_dir}/../..").ordered
        expect(subject).to receive(:delete_aws_instances).ordered
        expect(subject).to receive(:deploy_aws_bosh_lite).ordered
        expect(GitClient).to receive(:add_everything).ordered
        expect(GitClient).to receive(:safe_commit).with('recreated deployment edge-17.buildpacks.ci').ordered

        subject.recreate
      end
    end

    context 'iaas is azure or gcp' do
      let(:iaas) { 'azure' }

      it 'deploys bosh-lite to azure' do
        expect(subject).to receive(:target_bosh_director).ordered
        expect(subject).to receive(:delete_bosh_deployment).ordered
        expect(subject).to receive(:deploy_bosh_lite).ordered

        subject.recreate
      end
    end

    context 'bosh-lite is running' do
      it "updates bosh-lite admin password" do
        expect(subject).to receive(:update_admin_password)

        subject.recreate
      end

      it "cleans up the deployment manifests" do
        expect(subject).to receive(:cleanup_deployment_manifests)

        subject.recreate
      end
    end

    context 'bosh-lite is not running' do
      let(:bosh_lite_running) { false }

      it "exits" do
        expect{subject.recreate}.to raise_exception(SystemExit)
      end
    end
  end

  describe '#destroy' do
    before do
      allow(subject).to receive(:install_ssh_key)
      allow(subject).to receive(:delete_aws_instances)
      allow(subject).to receive(:target_bosh_director)
      allow(subject).to receive(:delete_bosh_deployment)
    end

    context 'iaas is aws' do
      it 'deletes the aws instance ' do
        expect(subject).to receive(:install_ssh_key).with("#{deployment_dir}/../..").ordered
        expect(subject).to receive(:delete_aws_instances).ordered

        subject.destroy
      end
    end

    context 'iaas is azure or gcp' do
      let(:iaas) { 'azure' }

      it 'deletes the azure bosh-lite deployment' do
        expect(subject).to receive(:target_bosh_director).ordered
        expect(subject).to receive(:delete_bosh_deployment).ordered

        subject.destroy
      end
    end
  end

  describe 'setup_bosh_connection' do
    before do
      allow(subject).to receive(:install_ssh_key)
      allow(subject).to receive(:target_bosh_director)
    end

    context 'iaas is aws' do
      it 'installs the ssh key' do
        expect(subject).to receive(:install_ssh_key).with("#{deployment_dir}/../..")
        subject.send :setup_bosh_connection
      end
    end

    context 'iaas is azure or gcp' do
      let(:iaas) { 'gcp' }

      it 'targets the BOSH director' do
        expect(subject).to receive(:target_bosh_director)
        subject.send :setup_bosh_connection
      end
    end
  end

  describe 'destroy_old_bosh_lite' do
    before do
      allow(subject).to receive(:delete_aws_instances)
      allow(subject).to receive(:delete_bosh_deployment)
    end

    context 'iaas is aws' do
      it 'deletes the aws instance' do
        expect(subject).to receive(:delete_aws_instances)
        subject.send :destroy_old_bosh_lite
      end
    end

    context 'iaas is azure or gcp' do
      let(:iaas) { 'gcp' }

      it 'deletes the bosh deployment' do
        expect(subject).to receive(:delete_bosh_deployment)
        subject.send :destroy_old_bosh_lite
      end
    end
  end

  describe 'deploy_new_bosh_lite' do
    before do
      allow(subject).to receive(:deploy_aws_bosh_lite)
      allow(subject).to receive(:deploy_bosh_lite)
      allow(GitClient).to receive(:add_everything)
      allow(GitClient).to receive(:safe_commit)
    end

    context 'iaas is aws' do
      it 'deploys bosh lite' do
        expect(subject).to receive(:deploy_aws_bosh_lite)
        subject.send :deploy_new_bosh_lite
      end

      it 'commits the AWS artifacts' do
        expect(GitClient).to receive(:add_everything)
        expect(GitClient).to receive(:safe_commit).with('recreated deployment edge-17.buildpacks.ci')
        subject.send :deploy_new_bosh_lite
      end
    end

    context 'iaas is azure or gcp' do
      let(:iaas) { 'gcp' }

      it 'deploys bosh lite' do
        expect(subject).to receive(:deploy_bosh_lite)
        subject.send :deploy_new_bosh_lite
      end
    end
  end


  describe '#deploy_aws_bosh_lite' do
    it "sets VAGRANT_CWD to deployment directory" do
      subject.send :deploy_aws_bosh_lite
      expect(ENV['VAGRANT_CWD']).to eq(deployment_dir)
    end

    it "runs vagrant up with aws provider" do
      expect(subject).to receive(:run_or_exit).with("/usr/bin/vagrant up --provider=aws")

      subject.send :deploy_aws_bosh_lite
    end
  end

  describe '#target_bosh_director' do
    it 'targets the director and logs in' do
      expect(subject).to receive(:run_or_exit).with("bosh target bosh.example.com")
      expect(subject).to receive(:run_or_exit).with("bosh login admin_director also_a_password")

      subject.send :target_bosh_director
    end
  end

  describe '#setup_bosh_lite_manifest' do
    let(:bosh_lite_dir) {File.join(deployment_dir, 'bosh-lite')}
    let(:manifest_contents) { <<~HEREDOC }
                                 ---
                                 director_uuid: NOT_A_UUID
                                 HEREDOC
    before do
      FileUtils.mkdir_p(bosh_lite_dir)

      File.write("#{bosh_lite_dir}/bosh-lite-template.yml", manifest_contents)

      allow(subject).to receive(:`).with('bosh status --uuid').and_return('aaaa-bbbb-cccc-dddd')
    end

    it 'creates a new bosh-lite.yml with an updated director_uuid' do
      subject.send :setup_bosh_lite_manifest

      bosh_lite_manifest_contents = YAML.load_file(File.join(deployment_dir, 'bosh-lite.yml') )
      expect(bosh_lite_manifest_contents['director_uuid']).to eq 'aaaa-bbbb-cccc-dddd'
    end
  end

  describe '#delete_bosh_deployment' do
    it 'deletes the bosh-lite deployment using the correct credentials' do
      expect(subject).to receive(:run_or_exit).with("echo 'yes' | bosh -u admin_director -p also_a_password delete deployment edge-17")

      subject.send :delete_bosh_deployment
    end
  end

  describe '#deploy_bosh_lite' do
    it 'sets up the bosh lite manifest, targets it, and deploys' do
      expect(subject).to receive(:setup_bosh_lite_manifest).ordered
      expect(subject).to receive(:run_or_exit).with("bosh deployment bosh-lite.yml").ordered
      expect(subject).to receive(:run_or_exit).with("echo 'yes' | bosh -u admin_director -p also_a_password deploy").ordered
      subject.send :deploy_bosh_lite
    end
  end

  describe '#install_ssh_key' do
    let(:install_dir) { Dir.mktmpdir }
    let(:keys_dir)    { File.join(install_dir, 'keys') }
    let(:key_file)    { File.join(keys_dir, 'bosh.pem') }

    before do
      FileUtils.mkdir_p(keys_dir)
    end

    after { FileUtils.rm_rf(install_dir) }

    it 'creates a bosh.pem file with the bosh private key' do
      subject.send(:install_ssh_key, install_dir)
      expect(File.read(key_file)).to eq('APRIVATESSHKEY')
    end

    it 'chmods and adds that key to the ssh agent' do
      expect(subject).to receive(:run_or_exit).with("chmod 0600 #{key_file}").ordered
      expect(subject).to receive(:run_or_exit).with("ssh-add #{key_file}").ordered
      subject.send(:install_ssh_key, install_dir)
    end

    it 'sets the BOSH_LITE_PRIVATE_KEY env var to key file path' do
      subject.send(:install_ssh_key, install_dir)
      expect(ENV['BOSH_LITE_PRIVATE_KEY']).to eq(key_file)
    end
  end

  describe '#update_admin_password' do
    before do
      allow(subject).to receive(:system).with("bosh -u admin_user -p admin -t" +
                                              " https://edge-17.buildpacks.ci.example.com" +
                                              " create user admin_user this_is_a_password").and_return(admin_update_succeeded)
    end

    context 'bosh update admin credentials worked' do
      let(:admin_update_succeeded) { true }

      it 'reports that it is working' do
        expect { subject.send :update_admin_password }.to output("Deployment working!\n").to_stdout
      end
    end

    context 'bosh update admin credentials did not work' do
      let(:admin_update_succeeded) { false }

      context 'iaas is aws' do
        it "reports that deployment failed, deletes aws instances, and exits" do
          expect(subject).to receive(:puts).with("Deployment failed: deleting instance")
          expect(subject).to receive(:delete_aws_instances)
          expect { subject.send :update_admin_password }.to raise_exception(SystemExit)
        end
      end

      context 'iaas is azure or gcp' do
        let(:iaas) { 'gcp' }

        it "reports that deployment failed and exits" do
          expect(subject).to receive(:puts).with("Deployment failed")
          expect { subject.send :update_admin_password }.to raise_exception(SystemExit)
        end
      end
    end
  end

  describe '#delete_aws_instances' do
    let(:lib_directory) { File.expand_path(File.dirname(__FILE__)) }
    let(:script_file)   { File.expand_path(File.join(lib_directory, '..', '..', 'scripts', 'terminate-bosh-lite')) }


    before do
      allow(subject).to receive(:run_or_exit)
      allow(FileUtils).to receive(:rm_rf)
    end

    it 'runs the terminate bosh lite script' do
      expect(subject).to receive(:run_or_exit).with(script_file)
      subject.send :delete_aws_instances
    end

    it 'removes the .vagrant file' do
      expect(FileUtils).to receive(:rm_rf).with('.vagrant')
      subject.send :delete_aws_instances
    end
  end

  describe '#wait_for_bosh_lite' do
    before do
      allow(subject).to receive(:system).with("curl -k --output /dev/null --silent --head --fail" +
                                              " https://edge-17.buildpacks.ci.example.com:25555/info").and_return(bosh_lite_is_running)
      allow(subject).to receive(:puts)
      allow(subject).to receive(:sleep)
    end

    context 'bosh lite is running' do
      let (:bosh_lite_is_running) { true }

      it 'returns true' do
        expect(subject.send :bosh_lite_running?).to eq true
      end
    end

    context 'bosh lite is not running' do
      let (:bosh_lite_is_running) { false }

      it 'waits for 30 min' do
        expect(subject).to receive(:sleep).with(10).exactly(180).times

        subject.send :bosh_lite_running?
      end

      it 'returns false' do
        expect(subject.send :bosh_lite_running?).to eq false
      end
    end
  end


  describe '#cleanup_deployment_manifests' do
    before do
      allow(FileUtils).to receive(:rm)
      allow(GitClient).to receive(:add_everything)
      allow(GitClient).to receive(:safe_commit)
    end

    context 'manifest yaml files present in deployment directory' do
      let(:manifest_file) { File.join(deployment_dir, 'some_manifest.yml') }

      before do
        File.write(manifest_file, '---')
      end

      it 'deletes all yaml files from deployment dir' do
        expect(FileUtils).to receive(:rm).with([ 'some_manifest.yml' ] )

        subject.send :cleanup_deployment_manifests
      end

      it 'adds and commits the deletion' do
        expect(GitClient).to receive(:add_everything)
        expect(GitClient).to receive(:safe_commit).with('remove deployment manifests for edge-17.buildpacks.ci')

        subject.send :cleanup_deployment_manifests
      end
    end

    context 'no manifest yaml files in deployment directory' do
      it 'does not try to delete yaml files from deployment dir' do
        expect(FileUtils).to_not receive(:rm)

        subject.send :cleanup_deployment_manifests
      end

      it 'does not git add or make a commit' do
        expect(GitClient).to_not receive(:add_everything)
        expect(GitClient).to_not receive(:safe_commit)

        subject.send :cleanup_deployment_manifests
      end
    end
  end
end

