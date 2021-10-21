require 'digest/md5'
require 'open-uri'

require_relative('update.rb')
require_relative('../../../binary-builder/recipe/php_common_recipes.rb')
require_relative('../../../binary-builder/recipe/php_recipe.rb')

def cache_key(name, version, klass)
    [name, version, klass]
end

def get_hash(name, version, klass, cache)
    key = cache_key(name, version, klass)

    if !cache[key]
        recipe = Object::const_get(klass).new(name, version)
        file = URI.open(recipe.url)
        cache[key] = Digest::MD5.hexdigest(file.read)
    end

    cache[key]
end

def update_hash(mod, cache)
    name = mod['name']
    version = mod['version']
    klass = mod['klass']
    md5 = mod['md5']

    if !version || version == 'nil'
        return
    end

    if !md5 || md5 == 'nil'
        puts "    > Computing hash for #{name} @ #{version}..."
        mod['md5'] = get_hash(name, version, klass, cache)
        puts "      Updated #{name} md5 to #{mod['md5']}"
    end
end

puts 'Updating module hashes...'

update_modules(&method(:update_hash))

puts 'Done!'
