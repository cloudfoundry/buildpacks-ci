#!/usr/bin/env ruby
# encoding: utf-8
require 'yaml'

# if there is an unsupported manifest
# check that every entry in the manifest is in the unsupported manifest

Dependency = Struct.new(:name, :version, :md5, :uri, :cf_stacks) do
  def self.from_manifest(dependencies)
    dependencies.map do |dependency|
      new(
        dependency['name'],
        dependency['version'],
        dependency['md5'],
        dependency['uri'],
        dependency['cf_stacks']
      )
    end
  end

  def ==(other)
    other.name == name &&
      other.version == version &&
      other.md5 == md5 &&
      other.uri == uri &&
      cf_stacks.all? { |stack| other.cf_stacks.include?(stack) }
  end

  def encode_with(coder)
    coder.tag = nil
    members.each { |m| coder[m.to_s] = send(m) }
  end
end

if File.exist?('manifest-including-unsupported.yml')
  manifest = YAML.load_file('manifest.yml')
  unsupported_manifest = YAML.load_file('manifest-including-unsupported.yml')

  manifest_dependencies = Dependency.from_manifest(manifest['dependencies'])
  unsupported_manifest_dependencies = Dependency.from_manifest(unsupported_manifest['dependencies'])

  unsupported_manifest_dependencies.map { |d| manifest_dependencies.delete(d) }

  if manifest_dependencies.any?
    puts '****missing from manifest-including-unsupported.yml***'
    puts manifest_dependencies.to_yaml
    exit 1
  end
end
