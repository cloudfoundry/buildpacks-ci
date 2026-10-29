require 'digest/md5'
require 'open-uri'

require_relative('update')

# Build the download URL for a PHP extension based on its name, version, and class.
# This replaces the old dependency on the Ruby binary-builder recipe classes
# (recipe/php_common_recipes.rb, recipe/php_recipe.rb) which were removed when
# binary-builder was rewritten in Go.
def download_url_for(name, version, klass)
  case klass
  when /^Pecl/i, 'PeclRecipe', 'AmqpPeclRecipe', 'MaxMindDBPeclRecipe'
    "https://pecl.php.net/get/#{name}-#{version}.tgz"
  when 'IonCubeRecipe'
    "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_#{version}.tar.gz"
  when 'LuaRecipe'
    "https://www.lua.org/ftp/lua-#{version}.tar.gz"
  when 'HiredisRecipe'
    "https://github.com/redis/hiredis/archive/v#{version}.tar.gz"
  when 'LibRdKafkaRecipe'
    "https://github.com/edenhill/librdkafka/archive/v#{version}.tar.gz"
  when 'LibSodiumRecipe'
    "https://github.com/jedisct1/libsodium/releases/download/#{version}/libsodium-#{version}.tar.gz"
  when 'RabbitMQRecipe'
    "https://github.com/alanxz/rabbitmq-c/archive/v#{version}.tar.gz"
  when 'PhalconRecipe'
    "https://github.com/phalcon/cphalcon/archive/v#{version}.tar.gz"
  when 'TidewaysXhprofRecipe'
    "https://github.com/tideways/php-xhprof-extension/archive/v#{version}.tar.gz"
  when 'PHPIRedisRecipe'
    "https://github.com/nrk/phpiredis/archive/v#{version}.tar.gz"
  when 'SnmpRecipe'
    # SNMP is a built-in PHP extension — no download needed.
    nil
  when /^FakePecl/i, 'FakePeclRecipe'
    # Built-in extensions compiled from PHP source — no download needed.
    nil
  else
    $stderr.puts "    WARNING: Unknown recipe class #{klass} for #{name} #{version} — skipping hash"
    nil
  end
end

def cache_key(name, version, klass)
  [name, version, klass]
end

def get_hash(name, version, klass, cache)
  key = cache_key(name, version, klass)

  unless cache[key]
    url = download_url_for(name, version, klass)
    unless url
      $stderr.puts "    Skipping #{name} #{version} (#{klass}) — no download URL"
      return nil
    end
    $stderr.puts "    Downloading #{url}..."
    file = URI.open(url)
    cache[key] = Digest::MD5.hexdigest(file.read)
  end

  cache[key]
end

def update_hash(dependency, cache)
  name = dependency['name']
  version = dependency['version']
  klass = dependency['klass']
  md5 = dependency['md5']

  return if !version || version == 'nil'

  return unless !md5 || md5 == 'nil'

  puts "    > Computing hash for #{name} @ #{version}..."
  hash = get_hash(name, version, klass, cache)
  if hash
    dependency['md5'] = hash
    puts "      Updated #{name} md5 to #{dependency['md5']}"
  else
    puts "      Skipped #{name} — no download URL for #{klass}"
  end
end

puts 'Updating module hashes...'

update_modules(&method(:update_hash))

puts 'Done!'
