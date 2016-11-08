# encoding: utf-8
require 'yaml'
require 'json'
require 'spec_helper'
require_relative '../../lib/buildpacks-ci-pipeline-updater'

describe BuildpacksCIPipelineUpdater do
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
      let(:cmd)  { "" }

      it 'sets the template option correctly' do
        expect(subject[:template]).to eq('template_name')
      end
    end
  end

  describe '#set_pipeline' do
    let(:target_name)                    { 'concourse-target' }
    let(:cmd)                            { "" }
    let(:pipeline_variable_filename)     { "" }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }

    subject do
      buildpacks_ci_pipeline_updater
        .set_pipeline(target_name: target_name,
                      name: pipeline_name,
                      cmd: cmd,
                      options: options,
                      pipeline_variable_filename: pipeline_variable_filename
                     )
    end

    describe 'input validation' do
      context "'--include' specified, pipeline name does not match" do
        let(:options)       { { include: 'target' } }
        let(:pipeline_name) { 'other-pipeline' }

        it 'returns without executing fly set-pipeline' do
          expect(buildpacks_ci_pipeline_updater).to_not receive(:system)
          subject
        end
      end

      context "'--exclude' specified, pipeline name matches the exclusion" do
        let(:options)       { { exclude: 'bad' } }
        let(:pipeline_name) { 'bad-pipeline' }

        it 'returns without executing fly set-pipeline' do
          expect(buildpacks_ci_pipeline_updater).to_not receive(:system)
          subject
        end
      end
    end

    describe 'building the fly command' do
      let(:target_name) { 'concourse-target' }
      let(:cmd)  { "erb this" }
      let(:options)       { { } }
      let(:pipeline_name) { 'our-pipeline' }
      let(:lpass_credential_files) { {
        lpass_concourse_private: 'private.yml',
        lpass_deployments_buildpacks: 'deployments.yml',
        lpass_repos_private_keys: 'keys.yml',
        lpass_bosh_release_private_keys: 'bosh.yml'
      } }

      before do
        allow(buildpacks_ci_pipeline_updater).to receive(:puts)
        allow(buildpacks_ci_pipeline_updater).to receive(:credential_filenames).and_return(lpass_credential_files)
      end

      it 'has a pipeline name' do
        expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/pipeline=our-pipeline/)
        subject
      end

      it 'has a concourse target' do
        expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/target=concourse-target/)
        subject
      end

      it 'has config set by an evaluated command' do
        expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/config=<\(erb this\)/)
        subject
      end

      it 'loads env vars from lpass credential files' do
        expect(buildpacks_ci_pipeline_updater).to receive(:system) do |fly_command|
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show private.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show deployments.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show keys.yml.*\)/
          expect(fly_command).to match /load-vars-from=\<\(.*lpass show bosh.yml.*\)/
        end
        subject
      end

      it 'loads env vars from public config' do
        expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/load-vars-from=public-config.yml/)
        subject
      end

      context 'when pipeline specific config is specified' do
        let(:pipeline_variable_filename) { "specific-config.yml" }

        it 'loads env vars from specified config file' do
          expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/load-vars-from=specific-config.yml/)
          subject
        end
      end

      context 'with PIPELINE_PREFIX set' do
        before { ENV['PIPELINE_PREFIX'] = 'prefix-' }

        after { ENV['PIPELINE_PREFIX'] = nil }

        it 'has a pipeline name' do
          expect(buildpacks_ci_pipeline_updater).to receive(:system).with(/pipeline=prefix-our-pipeline/)
          subject
        end
      end
    end
  end

  describe '#update_standard_pipelines' do
    let(:buildpacks_ci_pipeline_updater) { described_class.new }
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }

    subject { buildpacks_ci_pipeline_updater.update_standard_pipelines(target_name: target_name, options: options) }

    before do
      allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({})
      allow(Dir).to receive(:[]).with('pipelines/*.yml').and_return(%w(first.yml))
      allow(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).and_return(true)
    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For standard pipelines')

      subject
    end

    it 'looks for yaml files in the pipelines/ directory' do
      expect(Dir).to receive(:[]).with('pipelines/*.yml').and_return([])

      subject
    end

    it 'iterates over pipeline names' do
      allow(Dir).to receive(:[]).with('pipelines/*.yml').and_return(%w(first.yml second.yml))

      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).twice

      subject
    end

    it 'calls #set_pipeline with a target name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(target_name: target_name,
             name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls #set_pipeline with a pipeline name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(name: 'first',
             target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls #set_pipeline with command line options' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(options: {key: 'value'},
             target_name: anything, name: anything, cmd: anything)

      subject
    end

    describe 'erb command passed to #set_pipeline' do
      before do
        allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({'buildpacks-github-org' => 'buildpacks-github-org', 'run-oracle-php-tests' => 'run-oracle-php-tests'})
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /organization=buildpacks-github-org/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'sets a run_oracle_php_tests variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /run_oracle_php_tests=run-oracle-php-tests/,
               target_name: anything, name: anything, options: anything)

        subject
      end

      it 'passes in a pipeline filename' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /first\.yml/,
               target_name: anything, name: anything, options: anything)

        subject
      end
    end
  end
  
  describe '#update_bosh_lite_pipelines' do
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }

    subject { buildpacks_ci_pipeline_updater.update_bosh_lite_pipelines(target_name, options) }

    before do
      allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({})
      allow(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).and_return(true)

      allow(YAML).to receive(:load_file).with('edge-99.yml').and_return({})
      allow(YAML).to receive(:load_file).with('lts-11.yml').and_return({})

      allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml))
    end

    it 'prints a header' do
      expect(buildpacks_ci_pipeline_updater).to receive(:header).with('For bosh-lite pipelines')

      subject
    end

    it 'looks for yaml files in config/bosh-lite' do
      expect(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return([])

      subject
    end

    it 'gets full deployment names from yaml files' do
      expect(YAML).to receive(:load_file).with('edge-99.yml')

      subject
    end

    context 'when user has supplied a template option' do
      before do
        allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml lts-11.yml))
      end

      context 'and the template name is a bosh-lite template' do
        let(:options) { { template: 'lts' } }

        it 'runs when the pipeline name matches the template name' do
          expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything)

          subject
        end
      end

      context 'and the template name is not a bosh-lite template' do
        let(:options) { { template: 'not-a-bosh-lite' } }

        subject { buildpacks_ci_pipeline_updater.update_bosh_lite_pipelines(target_name, options) }

        it 'skips when the pipeline name does not match the template name' do
          expect(buildpacks_ci_pipeline_updater).not_to receive(:set_pipeline)

          subject
        end
      end
    end

    it 'iterates over deployment names' do
      allow(Dir).to receive(:[]).with('config/bosh-lite/*.yml').and_return(%w(edge-99.yml lts-11.yml))

      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).twice

      subject
    end

    it 'calls #set_pipeline with target name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(target_name: 'concourse-target',
             name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls #set_pipeline with deployment name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(name: 'edge-99',
             target_name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls #set_pipeline with pipeline_variable_file' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(pipeline_variable_filename: 'edge-99.yml',
          name: anything, target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls #set_pipeline with options' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(options: {key: 'value'},
             name: anything, target_name: anything, cmd: anything, pipeline_variable_filename: anything)

      subject
    end

    describe 'erb command passed to #set_pipeline' do
      before do
        allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({'domain-name' => 'domain.name'})
        allow(YAML).to receive(:load_file).with('edge-99.yml').and_return({'deployment-name' => 'full-deployment-name'})
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a domain_name variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /domain_name='domain\.name'/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a deployment_name variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /deployment_name=edge-99/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a full_deployment_name variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /full_deployment_name=full-deployment-name/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'passes in a pipeline filename based on the CF version' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /pipelines\/templates\/bosh-lite-cf-edge/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end
    end
  end

  describe '#update_buildpack_pipelines' do
    let(:target_name)                    { 'concourse-target' }
    let(:options)                        { { key: 'value' } }
    let(:buildpacks_ci_pipeline_updater) { described_class.new }

    subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(target_name, options) }

    before do
      allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({})
      allow(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).and_return(true)


      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(cobol.yml))
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
          expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything)

          subject
        end
      end

      context 'and the template name is not a buildpack template' do
        let(:options) { { template: 'not-a-buildpack' } }

        subject { buildpacks_ci_pipeline_updater.update_buildpack_pipelines(target_name, options) }

        it 'skips when the pipeline name does not match the template name' do
          expect(buildpacks_ci_pipeline_updater).not_to receive(:set_pipeline)

          subject
        end
      end
    end

    it 'iterates over buildpack names' do
      allow(Dir).to receive(:[]).with('config/buildpack/*.yml').and_return(%w(intercal.yml cobol.yml))

      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).with(anything).twice

      subject
    end

    it 'calls #set_pipeline with target name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(target_name: 'concourse-target',
             name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls #set_pipeline with buildpack name' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(name: 'cobol-buildpack',
             target_name: anything, cmd: anything, options: anything, pipeline_variable_filename: anything)

      subject
    end

    it 'calls #set_pipeline with pipeline_variable_file' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(pipeline_variable_filename: 'cobol.yml',
             name: anything, target_name: anything, cmd: anything, options: anything)

      subject
    end

    it 'calls #set_pipeline with options' do
      expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
        with(options: {key: 'value'},
             name: anything, target_name: anything, cmd: anything, pipeline_variable_filename: anything)

      subject
    end

    describe 'erb command passed to #set_pipeline' do
      before do
        allow(buildpacks_ci_pipeline_updater).to receive(:get_config).and_return({'buildpacks-github-org' => 'are-awesome'})
      end

      it 'includes `erb`' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /^erb/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets a language variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /language=cobol/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end

      it 'sets an organization variable' do
        expect(buildpacks_ci_pipeline_updater).to receive(:set_pipeline).
          with(cmd: /organization=are-awesome/,
               target_name: anything, name: anything, options: anything, pipeline_variable_filename: anything)

        subject
      end
    end
  end

  # describe '#get_cf_version_from_deployment_name'
  # describe '#get_config'
  # describe '#run!'
end
