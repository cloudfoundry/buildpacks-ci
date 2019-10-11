require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
config = YAML.load_file(File.join(buildpacks_ci_dir, 'pipelines/config/dependency-builds.yml'))
V3_DEP_IDS = config['v3_dep_ids']
V3_DEP_NAMES = config['v3_dep_names']

class Dependency
  attr_reader :id, :name, :version, :uri, :sha256, :stacks, :osl, :source, :source_sha256
  def initialize(dependency_name, resource_version, url, sha256, stacks, source_url, source_sha256)
      @id = V3_DEP_IDS.fetch(dependency_name, dependency_name)
      @name = V3_DEP_NAMES[dependency_name]
      @version = resource_version
      @uri = url
      @sha256 = sha256
      @stacks = stacks
      unless source_sha256.nil? or source_sha256 == ""
        @source = correct_source_url(source_url)
        @source_sha256 = source_sha256
      end
  end

  private
  def correct_source_url(source_url)
    if @id.include? 'miniconda'
      return "https://github.com/conda/conda/archive/#{version}.tar.gz"
    end
    source_url
  end
end