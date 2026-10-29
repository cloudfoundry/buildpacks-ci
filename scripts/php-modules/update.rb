require 'yaml'
require 'date'
require 'time'

def process_extension_file(cache, data, ext_file, dependency_type, f)
  (data.dig(*dependency_type) || []).each do |dependency|
    f.call(dependency, cache) unless (dependency['name'] == 'oci8' && ext_file.include?('php8-base-extensions.yml')) || dependency['name'] == 'rabbitmq'
  end
end

# EXTENSIONS_DIR points directly to the directory containing the extension YAML
# files. This supports multiple layouts:
#
#   - php-buildpack:   EXTENSIONS_DIR=php-buildpack/config/extensions
#   - binary-builder (pre-Phase 5):  EXTENSIONS_DIR=binary-builder/internal/php/assets
#   - binary-builder (post-Phase 5): EXTENSIONS_DIR=binary-builder/internal/php/testdata
#
# For backward compatibility, BINARY_BUILDER_DIR is still supported as a fallback
# (resolves to BINARY_BUILDER_DIR/internal/php/assets).
EXTENSIONS_DIR = if ENV.key?('EXTENSIONS_DIR')
                   ENV['EXTENSIONS_DIR']
                 else
                   binary_builder_dir = ENV.fetch('BINARY_BUILDER_DIR', File.expand_path('../../../binary-builder', __dir__))
                   File.join(binary_builder_dir, 'internal/php/assets')
                 end

EXTENSION_FILES = %w[
  php8-base-extensions.yml
  php81-extensions-patch.yml
  php82-extensions-patch.yml
  php83-extensions-patch.yml
  php84-extensions-patch.yml
  php85-extensions-patch.yml
].freeze

# update_modules iterates over all extension YAML files and calls the given block
# for each dependency. When dry_run is true, YAML files are NOT written back to disk.
def update_modules(dry_run: false, &f)
  cache = {}
  EXTENSION_FILES.each do |ext_file|
    path = File.join(EXTENSIONS_DIR, ext_file)

    unless File.exist?(path)
      $stderr.puts "WARNING: #{path} not found, skipping"
      next
    end

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

    File.write(path, data.to_yaml) unless dry_run
  end
end
