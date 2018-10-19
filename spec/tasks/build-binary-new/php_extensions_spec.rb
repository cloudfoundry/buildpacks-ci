describe 'PhpExtensions' do
  modules_72_only = ['libsodium']
  extensions_72_only = ['sodium']
  extensions_7_only = ['solr']

  it '7.2 extensions contains correct extensions' do
    php_yaml_72 = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', '..', 'tasks', 'build-binary-new', 'php72-extensions.yml'))
    php_modules_72 = php_yaml_72['native_modules'].map {|m| m['name'] }
    php_extensions_72 = php_yaml_72['extensions'].map {|m| m['name'] }

    expect(php_modules_72).to include(*modules_72_only)

    expect(php_extensions_72).to include(*extensions_72_only)
    expect(php_extensions_72).not_to include(*extensions_7_only)
  end

  it '7 extensions contains correct extensions' do
    php_yaml_7 = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', '..', 'tasks', 'build-binary-new', 'php7-extensions.yml'))
    php_modules_7 = php_yaml_7['native_modules'].map {|m| m['name'] }
    php_extensions_7 = php_yaml_7['extensions'].map {|m| m['name'] }

    expect(php_modules_7).not_to include(*modules_72_only)

    expect(php_extensions_7).to include(*extensions_7_only)
    expect(php_extensions_7).not_to include(*extensions_72_only)
  end
end
