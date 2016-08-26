# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require_relative '../../lib/state-of-bosh-lites'


describe StateOfBoshLites do
  let(:environments) {%w(edge-1.buildpacks.ci edge-2.buildpacks.ci lts-1.buildpacks.ci lts-2.buildpacks.ci)}

  before(:each) do
    allow(GitClient).to receive(:checkout_branch)
    allow(GitClient).to receive(:pull_current_branch)
    allow(GitClient).to receive(:get_current_branch)
  end

  describe '#get_states!' do
    subject { described_class.new }

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

      environments.each do |env|
        expect(subject).to have_received(:get_environment_status).with(env)
      end
    end
  end
  
  describe '#get_environment_status' do
    subject { described_class.new }

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
          state = subject.get_environment_status('edge-1.buildpacks.ci')
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
        state = subject.get_environment_status('lts-1.buildpacks.ci')
        expect(state['claimed']).to eq true
        expect(state['job']).to eq 'brats/brats-nodejs-lts build 21'
      end
    end
  end
end
