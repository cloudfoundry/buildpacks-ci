require 'json'

$buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{$buildpacks_ci_dir}/lib/git-client"

class BuildOutput
  attr_reader :git_client, :base_dir

  def initialize(name, git_client = GitClient, base_dir = 'builds-artifacts')
    @name             = name
    @git_client       = git_client
    @base_dir         = File.join(base_dir, 'binary-builds-new', name)
    FileUtils.mkdir_p(@base_dir)
  end

  def add_output(file, data)
    Dir.chdir(@base_dir) do
      File.write(file, data.to_json)
      @git_client.add_file(file)
    end
  end

  def commit_outputs(msg)
    Dir.chdir(@base_dir) do
      @git_client.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
      @git_client.set_global_config('user.name', 'CF Buildpacks Team CI Server')
      @git_client.safe_commit(msg)
    end
  end
end
