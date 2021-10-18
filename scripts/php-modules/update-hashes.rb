require 'digest/md5'
require 'open-uri'

require_relative('update.rb')
require_relative('../../../binary-builder/recipe/php_common_recipes.rb')
require_relative('../../../binary-builder/recipe/php_recipe.rb')

def get_hash(mod)
    recipe = Object::const_get(mod['klass']).new(mod['name'], mod['version'])
    file = URI.open(recipe.url)
    Digest::MD5.hexdigest(file.read)
end

def update_hash(mod)
    if !mod['version'] || mod['version'] == 'nil'
        return
    end

    if mod['md5'] == nil
        mod['md5'] = get_hash(mod)
        puts "    > Updated '#{mod['name']}' md5 to '#{mod['md5']}'"
    end
end

puts 'Updating module hashes...'

update_modules { |mod| update_hash(mod) }

puts 'Done!'
