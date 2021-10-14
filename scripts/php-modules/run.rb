#!/usr/bin/env ruby

require 'digest/md5'
require 'open-uri'
require 'yaml'

require File.expand_path("../../../binary-builder/recipe/php_common_recipes.rb")
require File.expand_path("../../../binary-builder/recipe/php_recipe.rb")

def get_hash(ext)
    recipe = Object::const_get(ext["klass"]).new(ext["name"], ext["version"])
    file = URI.open(recipe.url)
    Digest::MD5.hexdigest(file.read)
end

def update_ext(ext)
    if ext["md5"] == nil
        ext["md5"] = get_hash(ext)
        puts "    > Updating '#{ext["name"]}' md5 to '#{ext["md5"]}'"
    end
end

[
    "php7-base-extensions.yml",
    "php8-base-extensions.yml",
].each do |ext_file|
    path = File.expand_path(File.join("..", "..", "tasks", "build-binary-new", ext_file))

    puts "==> Processing: #{path}"
    data = YAML.load_file(path)
    extensions = data["extensions"]
    native_modules = data["native_modules"]

    extensions.each {|ext| update_ext(ext)}
    extensions
    native_modules.each {|ext| update_ext(ext)}

    data["extensions"] = extensions
    data["native_modules"] = native_modules
    File.write(path, data.to_yaml)
end

puts "Done!"