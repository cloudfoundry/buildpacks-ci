# encoding: utf-8
require 'open-uri'
require 'yaml'

class BuildpackDependency
  BUILDPACKS = %i(binary dotnet-core go nodejs php python ruby staticfile).freeze

  def self.for(dependency)
    buildpack_manifests.map do |name, manifest|
      if manifest['dependencies'].detect { |d| d['name'] == dependency.to_s }
        name
      end
    end.compact
  end

  private

  def self.buildpack_manifests
    @buildpack_manifests ||= BUILDPACKS.map do |name|
      [name, YAML.load(open("https://raw.githubusercontent.com/cloudfoundry/#{name}-buildpack/develop/manifest.yml"))]
    end
  end
end
