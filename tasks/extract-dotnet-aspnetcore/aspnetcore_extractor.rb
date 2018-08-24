require 'tmpdir'
require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'
require 'digest'

class Downloader
  def download(url, path)
    raise "Downloading dotnet sdk tar failed" unless system("curl", "-o", path, url)
  end
end

class AspnetcoreExtractor
  attr_reader :base_dir

  def initialize(
      stack,
      build_input,
      build_output,
      artifact_output,
      downloader = Downloader.new
  )
    @base_dir = Dir.tmpdir
    @stack = stack
    @build_input = build_input
    @build_output = build_output
    @artifact_output = artifact_output
    @downloader = downloader
  end

  def run
    sdk_tar = File.join(@base_dir, 'dotnet-sdk.tar.xz')
    sdk_dir = File.join(@base_dir, 'dotnet-sdk')
    aspcorenet_tar = File.join(@base_dir, "dotnet-aspnetcore.tar.xz")
    sdk_url = @build_input.url

    @downloader.download(sdk_url, sdk_tar)

    extract(sdk_tar, sdk_dir)

    version = retar(sdk_dir, aspcorenet_tar)

    create_dependency(aspcorenet_tar, version)
  end

  private

  def extract(sdk_tar, sdk_dir)
    FileUtils.mkdir_p(sdk_dir)
    raise "Extracting dotnet sdk failed" unless system("tar", "xf", sdk_tar, "-C", sdk_dir)
  end

  def retar(sdk_dir, aspcorenet_tar)
    versions = Dir["#{sdk_dir}/shared/Microsoft.AspNetCore.All/*", "#{sdk_dir}/shared/Microsoft.AspNetCore.App/*"]
      .map { |f| Pathname.new(f).basename.to_s }
      .uniq

    raise "There should only be one version of aspnetcore. Found #{versions}" unless versions.length == 1

    version = versions.first
    Dir.chdir(sdk_dir) do
      system("tar Jcf #{aspcorenet_tar} shared/Microsoft.AspNetCore.All/#{version} shared/Microsoft.AspNetCore.App/#{version} host *.txt") or raise "Tarring the dotnet aspnetcore assemblies failed"
    end

    version
  end

  def create_dependency(aspcorenet_tar, version)
    @build_input.copy_to_build_output

    out_data = {
      tracker_story_id: @build_input.tracker_story_id,
      version: version,
    }

    out_data.merge!(@artifact_output.move_dependency(
      'dotnet-aspnetcore',
      aspcorenet_tar,
      "dotnet-aspnetcore.#{version}.linux-amd64-#{@stack}",
      'tar.xz'
    ))

    @build_output.version = version
    @build_output.git_add_and_commit(out_data)

    out_data
  end
end