class BuildpacksCIConfiguration
  def concourse_private_filename
    ENV.fetch('LPASS_CONCOURSE_PRIVATE_FILE', 'Shared-Buildpacks/concourse-private.yml')
  end

  def deployments_buildpacks_filename
    ENV.fetch('LPASS_DEPLOYMENTS_BUILDPACKS_FILE',  'Shared-Buildpacks/deployments-buildpacks.yml')
  end

  def repos_private_keys_filename
    ENV.fetch('LPASS_REPOS_PRIVATE_KEYS_FILE', 'Shared-Buildpacks/buildpack-repos-private-keys.yml')
  end

  def bosh_release_private_keys_filename
    ENV.fetch('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE', 'Shared-Buildpacks/buildpack-bosh-release-repos-private-keys.yml')
  end

  def bosh_release_private_keys_filename_lts
    ENV.fetch('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE_LTS', 'Shared-Buildpacks/buildpack-bosh-release-repos-private-keys-lts.yml')
  end

  def git_repos_private_keys_filename
    ENV.fetch('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE', 'Shared-Buildpacks/git-repos-private-keys.yml')
  end

  def git_repos_private_keys_two_filename
    ENV.fetch('LPASS_GIT_REPOS_PRIVATE_KEYS_TWO_FILE', 'Shared-Buildpacks/git-repos-private-keys-two.yml')
  end

  def git_repos_private_keys_three_filename
    ENV.fetch('LPASS_GIT_REPOS_PRIVATE_KEYS_THREE_FILE', 'Shared-Buildpacks/git-repos-private-keys-three.yml')
  end

  def dockerhub_cflinuxfs2_credentials_filename
    ENV.fetch('LPASS_DOCKERHUB_CFLINUXFS2_CREDENTIALS_FILE', 'Shared-Buildpacks/dockerhub-cflinuxfs2.yml')
  end

  def organization
    YAML.load_file('public-config.yml')['buildpacks-github-org']
  end

  def run_oracle_php_tests?
    YAML.load_file('public-config.yml')['run-oracle-php-tests']
  end

  def bosh_lite_domain_name
    YAML.load_file('public-config.yml')['bosh-lite-domain-name']
  end

  def concourse_target_name
    ENV.fetch('CONCOURSE_TARGET_NAME', 'buildpacks')
  end
end
