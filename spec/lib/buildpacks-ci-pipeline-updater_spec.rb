# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require_relative '../../lib/buildpacks-ci-pipeline-updater'
require_relative '../../lib/buildpacks-ci-pipeline-update-command'

describe BuildpacksCIPipelineUpdater do
  let (:buildpacks_ci_configuration) { BuildpacksCIConfiguration.new }

  before do
    allow(BuildpacksCIConfiguration).to receive(:new).and_return(buildpacks_ci_configuration)
  end

  describe '#parse_args' do

    subject { described_class.new.parse_args(args) }

    context 'with --include specified' do
      let(:args) { %w(--include target_string) }

      it 'sets the include option correctly' do
        expect(subject[:include]).to eq('target_string')
      end
    end

    context 'with --exclude specified' do
      let(:args) { %w(--exclude bad_string) }

      it 'sets the exclude option correctly' do
        expect(subject[:exclude]).to eq('bad_string')
      end
    end

    context 'with --template specified' do
      let(:args) { %w(--template template_name) }
      let(:config_generation_command)  { "" }

      it 'sets the template option correctly' do
        expect(subject[:template]).to eq('template_name')
      end
    end
  end

  describe '#update_standard_pipelines' do
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:buildpacks_ci_pipeline_update_command) { BuildpacksCIPipelineUpdateCommand.new }
    let(:concourse_target_name)          { 'concourse-target' }
    let(:options)                        { { key: 'value' } }

    subject { buildpacks_ci_pipeline_updater.update_standard_pipelines(options) }

    before do
      allow(buildpacks_ci_configuration).to receive(:concourse_target_name).and_return(concourse_target_name)
      allow_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything).and_return(true)

      allow(Dir).to receive(:[]).with('pipelines/*.{erb,yml}').and_return(%w(first.yml.erb))
      allow(BuildpacksCIPipelineUpdateCommand).to receive(:new).and_return(buildpacks_ci_pipeline_update_command)

    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For standard pipelines')

      subject
    end

    it 'looks for yaml files in the pipelines/ directory' do
      expect(Dir).to receive(:[]).with('pipelines/*.{erb,yml}').and_return([])

      subject
    end

    it 'iterates over pipeline names' do
      allow(Dir).to receive(:[]).with('pipelines/*.{erb,yml}').and_return(%w(first.yml.erb second.yml))

      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything).twice

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with a target name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(concourse_target_name: concourse_target_name,
             pipeline_name: anything, config_generation_command: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with a pipeline name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(pipeline_name: 'first',
             concourse_target_name: anything, config_generation_command: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with command line options' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(options: {key: 'value'},
             concourse_target_name: anything, pipeline_name: anything, config_generation_command: anything)

      subject
    end

    describe 'erb command passed to BuildpacksCIPipelineUpdateCommand#run!' do
      before do
        allow(buildpacks_ci_configuration).to receive(:organization).and_return('buildpacks-github-org')
        allow(buildpacks_ci_configuration).to receive(:run_oracle_php_tests?).and_return(false)
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /^erb/,
               concourse_target_name: anything, pipeline_name: anything, options: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /organization=buildpacks-github-org/,
               concourse_target_name: anything, pipeline_name: anything, options: anything)

        subject
      end

      it 'sets a run_oracle_php_tests variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /run_oracle_php_tests=false/,
               concourse_target_name: anything, pipeline_name: anything, options: anything)

        subject
      end

      it 'passes in a pipeline filename' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /first\.yml\.erb/,
               concourse_target_name: anything, pipeline_name: anything, options: anything)

        subject
      end
    end

    describe 'asking BuildpackCIConfiguration for metadata' do
      it 'asks BuildpackCIConfiguration for the organization' do
        expect(buildpacks_ci_configuration).to receive(:organization)

        subject
      end

      it 'asks BuildpackCIConfiguration for the Concourse target name' do
        expect(buildpacks_ci_configuration).to receive(:concourse_target_name)

        subject
      end

      it 'asks BuildpackCIConfiguration whether PHP oracle tests should be run' do
        expect(buildpacks_ci_configuration).to receive(:run_oracle_php_tests?)

        subject
      end
    end
  end

  describe '#update_buildpack_pipelines' do
    let(:concourse_target_name)          { 'concourse-target' }
    let(:options)                        { { key: 'value' } }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:buildpacks_ci_pipeline_update_command) { BuildpacksCIPipelineUpdateCommand.new }

    subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(options) }

    before do
      allow(buildpacks_ci_configuration).to receive(:concourse_target_name).and_return(concourse_target_name)
      allow_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything).and_return(true)

      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(cobol.yml))
      allow(BuildpacksCIPipelineUpdateCommand).to receive(:new).and_return(buildpacks_ci_pipeline_update_command)
    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For buildpack pipelines')

      subject
    end

    it 'looks for yaml files in config/buildpack/' do
      expect(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return([])

      subject
    end

    context 'when user has supplied a template option' do
      before do
        allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(template-name.yml will-not-match.yml))
      end

      context 'and the template name is a buildpack template' do
        let(:options) { { template: 'template-name' } }

        it 'runs when the pipeline name matches the template name' do
          expect_any_instance_of(BuildpacksCIPipelineUpdateCommand).to receive(:run!).with(anything)

          subject
        end
      end

      context 'and the template name is not a buildpack template' do
        let(:options) { { template: 'not-a-buildpack' } }

        subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(options) }

        it 'skips when the pipeline name does not match the template name' do
          expect_any_instance_of(BuildpacksCIPipelineUpdateCommand).not_to receive(:run!)

          subject
        end
      end
    end

    it 'iterates over buildpack names' do
      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(intercal.yml cobol.yml))

      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).with(anything).twice

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with target name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(concourse_target_name: 'concourse-target',
             pipeline_name: anything, config_generation_command: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with buildpack name' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(pipeline_name: 'cobol-buildpack',
             concourse_target_name: anything, config_generation_command: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with pipeline_variable_file' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(pipeline_variable_filename: 'cobol.yml',
             pipeline_name: anything, concourse_target_name: anything, config_generation_command: anything, options: anything)

      subject
    end

    it 'calls BuildpacksCIPipelineUpdateCommand#run! with options' do
      expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
        with(options: {key: 'value'},
             pipeline_name: anything, concourse_target_name: anything, config_generation_command: anything, pipeline_variable_filename: anything)

      subject
    end

    describe 'erb command passed to BuildpacksCIPipelineUpdateCommand#run!' do
      before do
        allow(buildpacks_ci_configuration).to receive(:organization).and_return('buildpacks-github-org')
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /^erb/,
               concourse_target_name: anything, pipeline_name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a language variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /language=cobol/,
               concourse_target_name: anything, pipeline_name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_update_command).to receive(:run!).
          with(config_generation_command: /organization=buildpacks-github-org/,
               concourse_target_name: anything, pipeline_name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end
    end

    describe 'asking BuildpackCIConfiguration for metadata' do
      it 'asks BuildpackCIConfiguration for the organization' do
        expect(buildpacks_ci_configuration).to receive(:organization)

        subject
      end

      it 'asks BuildpackCIConfiguration for the Concourse target name' do
        expect(buildpacks_ci_configuration).to receive(:concourse_target_name)

        subject
      end
    end
  end

  describe '#run!' do
    let(:args) { [] }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }

    subject { buildpacks_ci_pipeline_updater.run!(args) }

    before do
      allow(buildpacks_ci_pipeline_updater).to receive(:check_if_lastpass_installed)
      allow(buildpacks_ci_pipeline_updater).to receive(:update_buildpack_pipelines)
      allow(buildpacks_ci_pipeline_updater).to receive(:update_standard_pipelines)
      allow(buildpacks_ci_pipeline_updater).to receive(:update_rootfs_pipelines)
    end

    context 'there is a template argument' do
      let(:args) { %w(--template=whatever_template) }

      it 'does not try to update standard pipelines' do
        expect(buildpacks_ci_pipeline_updater).to_not receive(:update_standard_pipelines)

        subject
      end
    end

    it 'updates buildpack pipelines' do
      expect(buildpacks_ci_pipeline_updater).to receive(:update_buildpack_pipelines).with({})

      subject
    end

    it 'updates standard pipelines' do
      expect(buildpacks_ci_pipeline_updater).to receive(:update_standard_pipelines).with({})

      subject
    end

    it 'updates the rootfs pipelines' do
      expect(buildpacks_ci_pipeline_updater).to receive(:update_rootfs_pipelines).with({})

      subject
    end
  end
end
