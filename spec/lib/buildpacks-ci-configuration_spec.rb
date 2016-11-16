require 'yaml'
require_relative '../../lib/buildpacks-ci-configuration'

describe BuildpacksCIConfiguration do

  describe '#concourse_private_filename' do
    subject { BuildpacksCIConfiguration.new.concourse_private_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('LPASS_CONCOURSE_PRIVATE_FILE').and_return('private.yml')

        expect(subject).to eq('private.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('LPASS_CONCOURSE_PRIVATE_FILE')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('Shared-Buildpacks/concourse-private.yml')
    end
  end

  describe '#deployments_buildpacks_filename' do
    subject { BuildpacksCIConfiguration.new.deployments_buildpacks_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('LPASS_DEPLOYMENTS_BUILDPACKS_FILE').and_return('deployment.yml')

        expect(subject).to eq('deployment.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('LPASS_DEPLOYMENTS_BUILDPACKS_FILE')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('Shared-Buildpacks/deployments-buildpacks.yml')
    end
  end

  describe '#repos_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.repos_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('LPASS_REPOS_PRIVATE_KEYS_FILE').and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('LPASS_REPOS_PRIVATE_KEYS_FILE')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('Shared-Buildpacks/buildpack-repos-private-keys.yml')
    end
  end

  describe '#git_repos_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.git_repos_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE').and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('Shared-Buildpacks/git-repos-private-keys.yml')
    end
  end

  describe '#bosh_release_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.bosh_release_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE').and_return('private_keys.yml')

        expect(subject).to eq('private_keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('Shared-Buildpacks/buildpack-bosh-release-repos-private-keys.yml')
    end
  end

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

  describe '#bosh_lite_domain_name' do
    subject { BuildpacksCIConfiguration.new.bosh_lite_domain_name }

    before do
      allow(YAML).to receive(:load_file).with('public-config.yml').
        and_return({'bosh-lite-domain-name' => 'domain.name'})
    end

    it 'loads the public-config.yml file' do
      expect(YAML).to receive(:load_file).with('public-config.yml')

      subject
    end

    it 'returns string from the yml data' do
      expect(subject).to eq('domain.name')
    end
  end

  describe '#concourse_target_name' do
    subject { BuildpacksCIConfiguration.new.concourse_target_name }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:[]).with('CONCOURSE_TARGET_NAME').and_return('concourse-target')

        expect(subject).to eq('concourse-target')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:[]).with('CONCOURSE_TARGET_NAME')

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to eq('buildpacks')
    end
  end
end
