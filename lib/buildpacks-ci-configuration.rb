class BuildpacksCIConfiguration
  def organization
    YAML.load_file('public-config.yml', permitted_classes: [Date, Time])['buildpacks-github-org']
  end

  def run_oracle_php_tests?
    YAML.load_file('public-config.yml', permitted_classes: [Date, Time])['run-oracle-php-tests']
  end

  def concourse_target_name
    ENV.fetch('CONCOURSE_TARGET_NAME', 'buildpacks')
  end
end
