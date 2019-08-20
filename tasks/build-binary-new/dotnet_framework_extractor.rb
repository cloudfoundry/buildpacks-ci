require 'tmpdir'
require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'
require 'digest'

class DotnetFrameworkExtractor
  attr_reader :base_dir

  def initialize(
    sdk_dir,
      stack,
      source_input,
      build_input,
      artifact_output
  )
    @base_dir = Dir.tmpdir
    @sdk_dir = sdk_dir
    @stack = stack
    @source_input = source_input
    @build_input = build_input
    @artifact_output = artifact_output
  end

  def extract_runtime(remove_frameworks)
    build_output = BuildOutput.new('dotnet-runtime')
    runtime_tar = File.join(@base_dir, "dotnet-runtime.tar.xz")

    if remove_frameworks
      write_runtime_file(@sdk_dir)
    end

    version = extract_framework_dep(@sdk_dir, runtime_tar, %w(Microsoft.NETCore.App), remove_frameworks)

    create_dependency(runtime_tar, version, @source_input, build_output, 'dotnet-runtime')
  end

  def extract_aspnetcore(remove_frameworks)
    build_output = BuildOutput.new('dotnet-aspnetcore')
    aspcorenet_tar = File.join(@base_dir, "dotnet-aspnetcore.tar.xz")

    version = extract_framework_dep(@sdk_dir, aspcorenet_tar, %w(Microsoft.AspNetCore.App Microsoft.AspNetCore.All), remove_frameworks)

    create_dependency(aspcorenet_tar, version, @source_input, build_output, 'dotnet-aspnetcore')
  end

  private

  def write_runtime_file(sdk_dir)
    Dir.chdir(sdk_dir) do
      runtime_glob = File.join("shared", "Microsoft.NETCore.App", "*")
      version = Pathname.new(Dir[runtime_glob].last()).basename.to_s

      File.open("RuntimeVersion.txt", "w") do |f|
        f.write(version)
      end
    end
  end

  def extract_framework_dep(sdk_dir, tar, package_names, remove_frameworks)
    Dir.chdir(sdk_dir) do
      paths = package_names.map {|package| File.join("shared", package)}
      paths += File.join("host", "fxr")
      version = Dir[File.join(paths.first, "*")]
                  .map {|path| Pathname.new(path).basename.to_s}
                  .sort_by {|version| Gem::Version.new(version)}
                  .last

      raise "Version #{version} of #{package_names.join('/')} contains metadata, exiting" if Gem::Version.new(version).prerelease?

      paths_with_version = paths.map {|path| File.join(path, version)}
      system("tar Jcf #{tar} #{paths_with_version.join(' ')} *.txt") or raise "Tarring the #{package_names.join(', ')} assemblies failed"

      if remove_frameworks
        FileUtils.rm_rf(paths)
      end

      return version
    end
  end

  def create_dependency(tar, version, source_input, build_output, framework_name)
    out_data = {
      tracker_story_id: @build_input.tracker_story_id,
      version: version,
      source: {url: source_input.url, sha256: source_input.sha256},
      git_commit_sha: source_input.git_commit_sha
    }

    out_data.merge!(@artifact_output.move_dependency(
      "#{framework_name}",
      tar,
      "#{framework_name}.#{version}.linux-amd64-#{@stack}",
      'tar.xz'
    ))

    build_output.add_output("#{version}.json", {tracker_story_id: @build_input.tracker_story_id})
    build_output.add_output("#{version}-#{@stack}.json", out_data)
    build_output.commit_outputs("Build #{framework_name} - #{version} - #{@stack}")

    out_data
  end
end
