require_relative('update.rb')
require_relative('../../tasks/check-for-latest-php-module-versions/common.rb')

def bump_version(mod)
    if !mod['version'] || mod['version'] == 'nil'
        return
    end

    url = url_for_type(mod['name'], mod['klass'])
    latest = current_pecl_version(mod['name']) if mod['klass'] =~ /PECL/i
    latest = current_github_version(url, ENV['GITHUB_TOKEN']) if url =~ %r{^https://github.com}

    if !latest || latest == 'Unknown'
        puts "    > WARNING! Could not determine latest version of '#{mod['name']}'. Manual check required."
        return
    end

    if mod['version'] != latest
        puts "    > Bumping '#{mod['name']}': #{mod['version']} -> #{latest}"
        mod['version'] = latest
        mod['md5'] = nil
    end
end

puts 'Bumping module versions...'

update_modules { |mod| bump_version(mod) }

puts 'Done!'
