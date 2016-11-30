# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/state-of-bosh-lites'

describe StateOfBoshLites do
  let(:gcp_environment_names) {%w(edge-1.buildpacks-gcp.ci edge-2.buildpacks-gcp.ci lts-1.buildpacks-gcp.ci lts-2.buildpacks-gcp.ci)}
  let(:aws_environment_names) {%w(edge-1.buildpacks.ci edge-2.buildpacks.ci lts-1.buildpacks.ci lts-2.buildpacks.ci)}
  let(:environments) { { 'aws' => aws_environment_names,
                         'gcp' => gcp_environment_names} }

  before(:each) do
    allow(GitClient).to receive(:checkout_branch)
    allow(GitClient).to receive(:pull_current_branch)
    allow(GitClient).to receive(:get_current_branch)
  end

  subject { described_class.new }

  describe '#get_states!' do
    context 'using git' do
      before(:each) do
        allow(GitClient).to receive(:get_current_branch).and_return('develop')
        allow(subject).to receive(:get_environment_status).and_return( {'claimed' => true, 'job' => 'php-buildpack/specs-develop build 13'} )
      end

      it 'switches to the resource-pools branch and back' do
        subject.get_states!

        expect(GitClient).to have_received(:checkout_branch).with('resource-pools')
        expect(GitClient).to have_received(:checkout_branch).with('develop')
      end

      it 'gets the status of all the environments' do
        subject.get_states!

        environments.each do |iaas, environment_names|
          environment_names.each do |env|
             expect(subject).to have_received(:get_environment_status).with(env, iaas)
          end
        end
      end
    end

    context 'using a separate resource pools directory' do
      let(:resource_pools_dir) { Dir.mktmpdir }

      before do
        allow(Dir).to receive(:chdir).and_call_original
        allow(subject).to receive(:get_environment_status).and_return( {'claimed' => true, 'job' => 'php-buildpack/specs-develop build 13'} )
      end

      after { FileUtils.rm_rf(resource_pools_dir) }

      it 'navigates into the resource pools directory' do
        expect(Dir).to receive(:chdir).with(resource_pools_dir)

        subject.get_states!(resource_pools_dir: resource_pools_dir)
      end

      it 'gets the status of all the environments' do
        subject.get_states!(resource_pools_dir: resource_pools_dir)

        environments.each do |iaas, environment_names|
          environment_names.each do |env|
             expect(subject).to have_received(:get_environment_status).with(env, iaas)
          end
        end
      end
    end
  end

  describe '#get_environment_status' do
    let(:list_of_commits) do
      commits = <<~HEREDOC
                   011826f brats/brats-nodejs-lts build 21 unclaiming: lts-1.buildpacks.ci
                   2cf8188 brats/brats-safe-lts build 22 unclaiming: lts-2.buildpacks.ci
                   ec3dae2 brats/brats-nodejs-lts build 21 claiming: lts-1.buildpacks.ci
                   f9beaf3 php-buildpack/specs-lts-develop build 17 unclaiming: lts-1.buildpacks.ci
                   2efac0 brats/brats-safe-lts build 22 claiming: lts-2.buildpacks.ci
                   b282077 brats/brats-jruby-lts build 22 unclaiming: lts-2.buildpacks.ci
                   573f188 brats/brats-jruby-lts build 22 claiming: lts-2.buildpacks.ci
                   0f2f335 brats/brats-php-lts build 21 unclaiming: lts-2.buildpacks.ci
                   92e6277 brats/brats-safe-edge build 21 unclaiming: edge-1.buildpacks.ci
                   f4a935f brats/brats-nodejs-edge build 21 unclaiming: edge-2.buildpacks.ci
                   HEREDOC
      commits.split("\n")
    end

    context 'the environment is unclaimed' do
      before(:each) do
        allow(GitClient).to receive(:get_list_of_one_line_commits).and_return(list_of_commits)
        allow(File).to receive(:exist?).with('cf-edge-environments/claimed/edge-1.buildpacks.ci').and_return(false)
        allow(File).to receive(:exist?).with('cf-edge-environments/unclaimed/edge-1.buildpacks.ci').and_return(true)
      end

      it 'returns the correct state + job' do
          state = subject.get_environment_status('edge-1.buildpacks.ci', 'aws')
          expect(state['claimed']).to eq false
          expect(state['job']).to eq 'brats/brats-safe-edge build 21'
      end
    end

    context 'the environment is claimed' do
      before(:each) do
        allow(GitClient).to receive(:get_list_of_one_line_commits).and_return(list_of_commits)
        allow(File).to receive(:exist?).with('cf-lts-environments/claimed/lts-1.buildpacks.ci').and_return(true)
        allow(File).to receive(:exist?).with('cf-lts-environments/unclaimed/lts-1.buildpacks.ci').and_return(false)
      end

      it 'returns the correct state + job' do
        state = subject.get_environment_status('lts-1.buildpacks.ci', 'aws')
        expect(state['claimed']).to eq true
        expect(state['job']).to eq 'brats/brats-nodejs-lts build 21'
      end
    end

    context 'the environment does not currently exist' do
      before(:each) do
        allow(GitClient).to receive(:get_list_of_one_line_commits).and_return(list_of_commits)
        allow(File).to receive(:exist?).with('cf-lts-gcp-environments/claimed/lts-1.buildpacks-gcp.ci').and_return(false)
        allow(File).to receive(:exist?).with('cf-lts-gcp-environments/unclaimed/lts-1.buildpacks-gcp.ci').and_return(false)
      end

      it 'is failing' do
        expect(subject.get_environment_status('lts-1.buildpacks-gcp.ci', 'gcp')).to be_nil
      end
    end
  end

  describe '#bosh_lite_in_pool?' do
    let(:deployment_id) { 'lts-1.buildpacks.ci' }

    before { allow(subject).to receive(:state_of_environments).and_return(state_of_environments) }

    context 'bosh lite is not in resource pool' do
      let(:state_of_environments) { [{ 'name' => 'lts-1.buildpacks.ci', 'status' => nil }] }

      it 'returns false' do
        expect(subject.bosh_lite_in_pool?(deployment_id)).to be_falsey
      end
    end

    context 'bosh lite is in resource pool' do
      let(:state_of_environments) { [{ 'name' => 'lts-1.buildpacks.ci', 'status' => {'claimed' => true, 'job' => 'job'} }] }

      it 'returns true' do
        expect(subject.bosh_lite_in_pool?(deployment_id)).to be_truthy
      end
    end
  end
end
