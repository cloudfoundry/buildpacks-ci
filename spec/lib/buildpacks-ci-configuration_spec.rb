require 'yaml'
require_relative '../../lib/buildpacks-ci-configuration'

describe BuildpacksCIConfiguration do

  describe '#concourse_private_filename' do
    subject { BuildpacksCIConfiguration.new.concourse_private_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_CONCOURSE_PRIVATE_FILE', anything).and_return('private.yml')

        expect(subject).to eq('private.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_CONCOURSE_PRIVATE_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('concourse-private.yml')
    end
  end

  describe '#deployments_buildpacks_filename' do
    subject { BuildpacksCIConfiguration.new.deployments_buildpacks_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_DEPLOYMENTS_BUILDPACKS_FILE', anything).and_return('deployment.yml')

        expect(subject).to eq('deployment.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_DEPLOYMENTS_BUILDPACKS_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('deployments-buildpacks.yml')
    end
  end

  describe '#repos_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.repos_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_REPOS_PRIVATE_KEYS_FILE', anything).and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_REPOS_PRIVATE_KEYS_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('buildpack-repos-private-keys.yml')
    end
  end

  describe '#git_repos_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.git_repos_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE', anything).and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('git-repos-private-keys.yml')
    end
  end

  describe '#git_repos_private_keys_two_filename' do
    subject { BuildpacksCIConfiguration.new.git_repos_private_keys_two_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_TWO_FILE', anything).and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_TWO_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('git-repos-private-keys-two.yml')
    end
  end

  describe '#dockerhub_cflinuxfs2_credentials_filename' do
    subject { BuildpacksCIConfiguration.new.dockerhub_cflinuxfs2_credentials_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_DOCKERHUB_CFLINUXFS2_CREDENTIALS_FILE', anything).and_return('creds.yml')

        expect(subject).to eq('creds.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_DOCKERHUB_CFLINUXFS2_CREDENTIALS_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('dockerhub-cflinuxfs2.yml')
    end
  end

  describe '#git_repos_private_keys_three_filename' do
    subject { BuildpacksCIConfiguration.new.git_repos_private_keys_three_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_THREE_FILE', anything).and_return('keys.yml')

        expect(subject).to eq('keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_GIT_REPOS_PRIVATE_KEYS_THREE_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('git-repos-private-keys-three.yml')
    end
  end

  describe '#bosh_release_private_keys_filename' do
    subject { BuildpacksCIConfiguration.new.bosh_release_private_keys_filename }

    context 'configured by env variable' do
      it 'returns the value of the env var' do
        allow(ENV).to receive(:fetch).with('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE', anything).and_return('private_keys.yml')

        expect(subject).to eq('private_keys.yml')
      end

      it 'asks ENV for the value' do
        expect(ENV).to receive(:fetch).with('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE', anything)

        subject
      end
    end

    it 'has a default value' do
      expect(subject).to include('buildpack-bosh-release-repos-private-keys.yml')
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
