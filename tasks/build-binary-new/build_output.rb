require 'json'

$buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{$buildpacks_ci_dir}/lib/git-client"

class BuildOutput
  attr_reader :git_client, :base_dir

  def initialize(name, version, stack, tracker_story_id, git_client = GitClient, base_dir = 'builds-artifacts')
    @name             = name
    @version          = version
    @stack            = stack
    @tracker_story_id = tracker_story_id
    @git_client = git_client
    @base_dir = base_dir
  end

  def git_add_and_commit(out_data)
    Dir.chdir(@base_dir) do
      @git_client.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
      @git_client.set_global_config('user.name', 'CF Buildpacks Team CI Server')

      FileUtils.mkdir_p(File.join('binary-builds-new', @name))
      out_file = File.join('binary-builds-new', @name, "#{@version}-#{@stack}.json")
      File.write(out_file, out_data.to_json)

      @git_client.add_file(out_file)
      @git_client.safe_commit("Build #{@name} - #{@version} - #{@stack} [##{@tracker_story_id}]")
    end
  end
end