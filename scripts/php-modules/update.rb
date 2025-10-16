require 'yaml'

def process_extension_file(cache, data, ext_file, dependency_type, f)
  (data.dig(*dependency_type) || []).each do |dependency|
    f.call(dependency, cache) unless (dependency['name'] == 'oci8' && ext_file.include?('php8-base-extensions.yml')) || dependency['name'] == 'rabbitmq'
  end
end

def update_modules(&f)
  cache = {}
  %w[php8-base-extensions.yml php81-extensions-patch.yml php82-extensions-patch.yml php83-extensions-patch.yml].each do |ext_file|
    path = File.expand_path("../../tasks/build-binary-new/#{ext_file}")

    puts "==> Processing: #{path}"
    data = YAML.load_file(path, permitted_classes: [Date, Time])

    extensions = ['extensions']
    native_modules = ['native_modules']

    if File.basename(path).include? 'patch'
      extensions.append('additions')
      native_modules.append('additions')
    end

    process_extension_file(cache, data, ext_file, extensions, f)
    process_extension_file(cache, data, ext_file, native_modules, f)

    File.write(path, data.to_yaml)
  end
end
