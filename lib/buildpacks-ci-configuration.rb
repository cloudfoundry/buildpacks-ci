class BuildpacksCIConfiguration
  def concourse_private_filename
    ENV.fetch('LPASS_CONCOURSE_PRIVATE_FILE', 'Shared-CF\ Buildpacks/concourse-private.yml')
  end

  def repos_private_keys_filename
    ENV.fetch('LPASS_REPOS_PRIVATE_KEYS_FILE', 'Shared-CF\ Buildpacks/buildpack-repos-private-keys.yml')
  end

  def bosh_release_private_keys_filename
    ENV.fetch('LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE', 'Shared-CF\ Buildpacks/buildpack-bosh-release-repos-private-keys.yml')
  end

  def git_repos_private_keys_filename
    ENV.fetch('LPASS_GIT_REPOS_PRIVATE_KEYS_FILE', 'Shared-CF\ Buildpacks/git-repos-private-keys.yml')
  end

  def git_repos_private_keys_three_filename
    ENV.fetch('LPASS_GIT_REPOS_PRIVATE_KEYS_THREE_FILE', 'Shared-CF\ Buildpacks/git-repos-private-keys-three.yml')
  end

  def organization
    YAML.load_file('public-config.yml')['buildpacks-github-org']
  end

  def run_oracle_php_tests?
    YAML.load_file('public-config.yml')['run-oracle-php-tests']
  end

  def concourse_target_name
    ENV.fetch('CONCOURSE_TARGET_NAME', 'buildpacks')
  end
end
