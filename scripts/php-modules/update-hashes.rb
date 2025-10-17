require 'digest/md5'
require 'open-uri'

require_relative('update')
require_relative('../../../binary-builder/recipe/php_common_recipes')
require_relative('../../../binary-builder/recipe/php_recipe')

def cache_key(name, version, klass)
  [name, version, klass]
end

def get_hash(name, version, klass, cache)
  key = cache_key(name, version, klass)

  unless cache[key]
    recipe = Object.const_get(klass).new(name, version)
    file = URI.open(recipe.url)
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
  dependency['md5'] = get_hash(name, version, klass, cache)
  puts "      Updated #{name} md5 to #{dependency['md5']}"
end

puts 'Updating module hashes...'

update_modules(&method(:update_hash))

puts 'Done!'
