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

def bump_version(mod, cache)
    name = mod['name']
    version = mod['version']
    klass = mod['klass']

    if !version || version == 'nil'
        return
    end

    url = url_for_type(name, klass)
    latest = get_latest(name, klass, url, cache)

    if !latest || latest == 'Unknown'
        puts "    > WARNING! Could not determine latest version of #{name}. Manual check required (URL: #{url || '<none>'})."
        return
    end

    if version != latest
        puts "    > Bumping #{name}: #{version} -> #{latest}"
        mod['version'] = latest
        mod['md5'] = nil
    end
end

puts 'Bumping module versions...'

update_modules(&method(:bump_version))

puts 'Done!'
