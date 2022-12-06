require 'yaml'

def update_modules(&f)
  cache = {}
  %w[php8-base-extensions.yml php81-extensions-patch.yml].each do |ext_file|
    path = File.expand_path("../../tasks/build-binary-new/#{ext_file}")

    puts "==> Processing: #{path}"
    data = YAML.load_file(path)

    extensions_ref = ['extensions']
    native_modules_ref = ['native_modules']

    if File.basename(path).include? 'patch'
      extensions_ref = extensions_ref.append('additions')
      native_modules_ref = native_modules_ref.append('additions')
    end

    (data.dig(*extensions_ref) || []).each { |mod| f.call(mod, cache) }
    (data.dig(*native_modules_ref) || []).each { |mod| f.call(mod, cache) }

    File.write(path, data.to_yaml)
  end
end
