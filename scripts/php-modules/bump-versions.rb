require_relative 'update'
require_relative '../../tasks/check-for-latest-php-module-versions/common'

# Define a method to calculate the cache key
def cache_key(name, klass)
  [name, klass]
end

# Define a method to get the latest version based on various conditions
def get_latest_version(name, klass, url, cache)
  key = cache_key(name, klass)

  # Check if the version is not already cached
  unless cache[key]
    # Determine the latest version based on different conditions
    latest = if klass =~ /PECL/i
               current_pecl_version(name)
             elsif name =~ /ioncube/i
               current_ioncube_version(url)
             elsif name =~ /maxminddb/i
               current_pecl_version(name)
             elsif name =~ /phpiredis/i
               current_github_version(url, 'tag', ENV.fetch('GITHUB_TOKEN', nil))
             elsif name =~ /lua/i
               current_lua_version(url)
             elsif url =~ %r{^https://github.com}
               current_github_version(url, 'release', ENV.fetch('GITHUB_TOKEN', nil))
             else
               raise "Unknown module type: #{name} (#{klass})"
             end

    # Cache the latest version
    cache[key] = latest
  end

  cache[key]
end

# Define a method to bump the version of a dependency
def bump_dependency_version(dependency, cache)
  name = dependency['name']
  version = dependency['version']
  klass = dependency['klass']

  # Check if the version is missing or set to 'nil'
  return if !version || version == 'nil'

  puts "    > Getting the latest version of #{name} (#{klass})..."
  url = url_for_type(name, klass)
  latest = get_latest_version(name, klass, url, cache)

  # Check if the latest version could not be determined
  if !latest || latest == 'Unknown'
    puts "      WARNING! Could not determine the latest version of #{name}. Manual check required (URL: #{url || '<none>'})."
    return
  end

  # Check if a version bump is required
  if version == latest
    puts "      No bump required (current version: #{version})"
  else
    puts "      Bumped #{name}: #{version} -> #{latest}"
    dependency['version'] = latest
    dependency['md5'] = nil
  end
end

# Main script
puts 'Bumping module versions...'

# Use the update_modules method to iterate and bump version for each module
update_modules(&method(:bump_dependency_version))

puts 'Done!'
