# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require_relative '../../lib/buildpacks-ci-pipeline-update-command'
require_relative '../../lib/buildpacks-ci-configuration'

describe BuildpacksCIPipelineUpdateCommand do
  describe '#run!' do
    let(:concourse_target_name)          { 'concourse-target' }
    let(:config_generation_command)      { '' }
    let(:pipeline_variable_filename)     { '' }
    let(:buildpacks_ci_pipeline_update_command) { described_class.new }
    subject do
      buildpacks_ci_pipeline_update_command
        .run!(concourse_target_name: concourse_target_name,
                      pipeline_name: pipeline_name,
                      config_generation_command: config_generation_command,
                      options: options,
                      pipeline_variable_filename: pipeline_variable_filename
                     )
    end

    describe 'input validation' do
      context "'--include' specified, pipeline name does not match" do
        let(:options)       { { include: 'target' } }
        let(:pipeline_name) { 'other-pipeline' }

        it 'returns without executing fly set-pipeline' do
          expect(buildpacks_ci_pipeline_update_command).to_not receive(:system)
          subject
        end
      end

      context "'--exclude' specified, pipeline name matches the exclusion" do
        let(:options)       { { exclude: 'bad' } }
        let(:pipeline_name) { 'bad-pipeline' }

        it 'returns without executing fly set-pipeline' do
          expect(buildpacks_ci_pipeline_update_command).to_not receive(:system)
          subject
        end
      end
    end

    describe 'building the fly command' do
      let(:concourse_target_name) { 'concourse-target' }
      let(:config_generation_command)  { 'erb this' }
      let(:options)       { { } }
      let(:pipeline_name) { 'our-pipeline' }
      let(:buildpacks_ci_configuration) { BuildpacksCIConfiguration.new }

      before do
        allow(buildpacks_ci_pipeline_update_command).to receive(:puts)
        allow(BuildpacksCIConfiguration).to receive(:new).and_return(buildpacks_ci_configuration)
      end

      it 'has a pipeline name' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/pipeline=our-pipeline/)
        subject
      end

      it 'has a concourse target' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/target=concourse-target/)
        subject
      end

      it 'has config set by an evaluated command' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/config=<\(erb this\)/)
        subject
      end

      it 'loads env vars from lpass credential files' do
        allow(buildpacks_ci_configuration).to receive(:concourse_private_filename).and_return('private.yml')
        allow(buildpacks_ci_configuration).to receive(:deployments_buildpacks_filename).and_return('deployments.yml')
        allow(buildpacks_ci_configuration).to receive(:repos_private_keys_filename).and_return('keys.yml')
        allow(buildpacks_ci_configuration).to receive(:git_repos_private_keys_filename).and_return('git_keys.yml')
        allow(buildpacks_ci_configuration).to receive(:bosh_release_private_keys_filename).and_return('bosh.yml')
        expect(buildpacks_ci_pipeline_update_command).to receive(:system) do |fly_command|
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show private.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show deployments.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show keys.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show git_keys.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show bosh.yml.*\)/
        end
        subject
      end

      it 'loads env vars from public config' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/load-vars-from=public-config.yml/)
        subject
      end

      context 'when pipeline specific config is specified' do
        let(:pipeline_variable_filename) { 'specific-config.yml' }

        it 'loads env vars from specified config file' do
          expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/load-vars-from=specific-config.yml/)
          subject
        end
      end

      context 'with PIPELINE_PREFIX set' do
        before { ENV['PIPELINE_PREFIX'] = 'prefix-' }

        after { ENV['PIPELINE_PREFIX'] = nil }

        it 'has a pipeline name' do
          expect(buildpacks_ci_pipeline_update_command).to receive(:system).with(/pipeline=prefix-our-pipeline/)
          subject
        end
      end

      describe 'asking BuildpackCIConfiguration for credential filenames' do
        before do
          allow(buildpacks_ci_pipeline_update_command).to receive(:system)
        end

        it 'gets the concourse private filename' do
          expect(buildpacks_ci_configuration).to receive(:concourse_private_filename)

          subject
        end

        it 'gets the concourse buildpacks deployments filename' do
          expect(buildpacks_ci_configuration).to receive(:deployments_buildpacks_filename)

          subject
        end

        it 'gets the concourse repo private keys filename' do
          expect(buildpacks_ci_configuration).to receive(:repos_private_keys_filename)

          subject
        end

        it 'gets the concourse git repo private keys filename' do
          expect(buildpacks_ci_configuration).to receive(:git_repos_private_keys_filename)

          subject
        end

        it 'gets the concourse BOSH release private keys filename' do
          expect(buildpacks_ci_configuration).to receive(:bosh_release_private_keys_filename)

          subject
        end
      end
    end
  end
end
