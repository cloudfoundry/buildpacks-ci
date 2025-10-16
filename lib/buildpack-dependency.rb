require 'open-uri'
require 'yaml'

class BuildpackDependency
  BUILDPACKS = %i[apt binary dotnet-core go hwc nodejs php python ruby staticfile].freeze

  def self.for(dependency)
    buildpack_manifests.map do |name, manifest|
      name if manifest['dependencies'].detect { |d| d['name'] == dependency.to_s }
    end.compact
  end

  def self.buildpack_manifests
    @buildpack_manifests ||= BUILDPACKS.map do |name|
      [name, YAML.load(URI.open("https://raw.githubusercontent.com/cloudfoundry/#{name}-buildpack/develop/manifest.yml"), permitted_classes: [Date, Time])]
    end
  end
end
