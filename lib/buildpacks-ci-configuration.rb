class BuildpacksCIConfiguration
  def concourse_private_filename
    ENV['LPASS_CONCOURSE_PRIVATE_FILE'] || 'Shared-Buildpacks/concourse-private.yml'
  end

  def deployments_buildpacks_filename
    ENV['LPASS_DEPLOYMENTS_BUILDPACKS_FILE'] || 'Shared-Buildpacks/deployments-buildpacks.yml'
  end

  def repos_private_keys_filename
    ENV['LPASS_REPOS_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-repos-private-keys.yml'
  end

  def bosh_release_private_keys_filename
    ENV['LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-bosh-release-repos-private-keys.yml'
  end

  def git_repos_private_keys_filename
    ENV['LPASS_GIT_REPOS_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/git-repos-private-keys.yml'
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
    ENV['CONCOURSE_TARGET_NAME'] || 'buildpacks'
  end
end
