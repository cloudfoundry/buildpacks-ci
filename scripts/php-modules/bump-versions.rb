require 'json'
require 'time'

require_relative 'update'
require_relative '../../tasks/check-for-latest-php-module-versions/common'

# Parse command-line flags.
DRY_RUN = ARGV.include?('--dry-run')
FORMAT_JSON = ARGV.include?('--format=json')

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

# Collect results when running in dry-run mode.
$report = { outdated: [], up_to_date_count: 0, error_count: 0, errors: [] }

# Define a method to bump (or check) the version of a dependency
def bump_dependency_version(dependency, cache)
  name = dependency['name']
  version = dependency['version']
  klass = dependency['klass']

  # Check if the version is missing or set to 'nil'
  return if !version || version == 'nil'

  $stderr.puts "    > Getting the latest version of #{name} (#{klass})..." unless FORMAT_JSON
  url = url_for_type(name, klass)

  begin
    latest = get_latest_version(name, klass, url, cache)
  rescue StandardError => e
    $report[:error_count] += 1
    $report[:errors] << { name: name, klass: klass, message: e.message }
    $stderr.puts "      ERROR: #{e.message}" unless FORMAT_JSON
    return
  end

  # Check if the latest version could not be determined
  if !latest || latest == 'Unknown'
    $report[:error_count] += 1
    $report[:errors] << { name: name, klass: klass, message: "Could not determine latest version (URL: #{url || '<none>'})" }
    $stderr.puts "      WARNING! Could not determine the latest version of #{name}. Manual check required (URL: #{url || '<none>'})." unless FORMAT_JSON
    return
  end

  # Check if a version bump is required
  if version == latest
    $report[:up_to_date_count] += 1
    $stderr.puts "      No bump required (current version: #{version})" unless FORMAT_JSON
  else
    $report[:outdated] << { name: name, klass: klass, current: version, latest: latest }
    if DRY_RUN
      $stderr.puts "      OUTDATED #{name}: #{version} -> #{latest}" unless FORMAT_JSON
    else
      $stderr.puts "      Bumped #{name}: #{version} -> #{latest}" unless FORMAT_JSON
      dependency['version'] = latest
      dependency['md5'] = nil
    end
  end
end

# Main script
$stderr.puts "#{DRY_RUN ? 'Checking' : 'Bumping'} module versions..."

update_modules(dry_run: DRY_RUN, &method(:bump_dependency_version))

if FORMAT_JSON
  output = {
    checked_at: Time.now.utc.iso8601,
    outdated: $report[:outdated],
    up_to_date_count: $report[:up_to_date_count],
    error_count: $report[:error_count],
    errors: $report[:errors]
  }
  puts JSON.pretty_generate(output)
else
  puts ''
  if $report[:outdated].any?
    puts "=== #{$report[:outdated].length} extension(s) outdated ==="
    $report[:outdated].each do |item|
      puts "  #{item[:name]} (#{item[:klass]}): #{item[:current]} -> #{item[:latest]}"
    end
  else
    puts '=== All extensions are up to date ==='
  end
  if $report[:errors].any?
    puts "\n=== #{$report[:error_count]} error(s) ==="
    $report[:errors].each do |err|
      puts "  #{err[:name]}: #{err[:message]}"
    end
  end
  puts "\nDone!"
end
