require_relative('update.rb')
require_relative('../../tasks/check-for-latest-php-module-versions/common.rb')

def cache_key(name, klass)
  [name, klass]
end

def get_latest(name, klass, url, cache)
  key = cache_key(name, klass)

  if !cache[key]
    latest = current_pecl_version(name) if klass =~ /PECL/i
    latest = current_github_version(url, ENV['GITHUB_TOKEN']) if url =~ %r{^https://github.com}
    cache[key] = latest
  end

  cache[key]
end

def bump_version(dependency, cache)
  name = dependency['name']
  version = dependency['version']
  klass = dependency['klass']

  if !version || version == 'nil'
    return
  end

  puts "    > Getting latest version of #{name} (#{klass})..."
  url = url_for_type(name, klass)
  latest = get_latest(name, klass, url, cache)

  if !latest || latest == 'Unknown'
    puts "      WARNING! Could not determine latest version of #{name}. Manual check required (URL: #{url || '<none>'})."
    return
  end

  if version != latest
    puts "      Bumped #{name}: #{version} -> #{latest}"
    dependency['version'] = latest
    dependency['md5'] = nil
  else
    puts "      No bump required (current version: #{version})"
  end
end

puts 'Bumping module versions...'

update_modules(&method(:bump_version))

puts 'Done!'
