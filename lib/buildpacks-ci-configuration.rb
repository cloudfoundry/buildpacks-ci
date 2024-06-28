class BuildpacksCIConfiguration
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
