require 'yaml'
require_relative '../../lib/buildpacks-ci-configuration'

describe BuildpacksCIConfiguration do

  describe '#organization' do
    subject { BuildpacksCIConfiguration.new.organization }

    before do
      allow(YAML).to receive(:load_file).with('public-config.yml').
        and_return({'buildpacks-github-org' => 'github-org-name'})
    end

    it 'loads the public-config.yml file' do
      expect(YAML).to receive(:load_file).with('public-config.yml')

      subject
    end

    it 'returns an organization from the yml data' do
      expect(subject).to eq('github-org-name')
    end
  end

  describe '#run_oracle_php_tests?' do
    subject { BuildpacksCIConfiguration.new.run_oracle_php_tests? }

    before do
      allow(YAML).to receive(:load_file).with('public-config.yml').
        and_return({'run-oracle-php-tests' => true})
    end

    it 'loads the public-config.yml file' do
      expect(YAML).to receive(:load_file).with('public-config.yml')

      subject
    end

    it 'returns boolean from the yml data' do
      expect(subject).to eq(true)
    end
  end

  describe '#concourse_target_name' do
    subject { BuildpacksCIConfiguration.new.concourse_target_name }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('CONCOURSE_TARGET_NAME', anything).and_return('concourse-target')

        expect(subject).to eq('concourse-target')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('CONCOURSE_TARGET_NAME', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('buildpacks')
    end
  end
end
