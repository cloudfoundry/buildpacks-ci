#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'
require 'pathname'
require 'fileutils'
require 'digest'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

class ExtractDotnetFramework
  def initialize(buildpacks_ci_dir)
    @buildpacks_ci_dir = buildpacks_ci_dir
    binary_built_dir = File.expand_path(File.join(@buildpacks_ci_dir, '..', 'built-yaml'))
    git_commit_message = GitClient.last_commit_message(binary_built_dir, 0, "binary-built-output/dotnet-built.yml")
    git_commit_message.gsub!(/Build(.*)\n\n/,'')
    git_commit_message.gsub!(/\n\n\[ci skip\]/,'')

    build_info = YAML.load(git_commit_message)
    @dotnet_sdk_filename = build_info['filename'].gsub('binary-builder/', '')
    @dotnet_sdk_git_sha = build_info['source git-commit-sha']
    @dotnet_sdk_source_url = build_info['source url']

    @dotnet_sdk_tar = File.join("/tmp", "dotnet_sdk.tar.xz")
    @dotnet_sdk_dir = File.join("/tmp", "dotnet_sdk")
  end

  def run
    download
    extract
    retar
    write_yaml
  end

  private

  def download
    dotnet_sdk_url = "https://buildpacks.cloudfoundry.org/dependencies/dotnet/#{@dotnet_sdk_filename}"
    raise "Downloading dotnet sdk tar failed" unless system("curl", "-o", @dotnet_sdk_tar, dotnet_sdk_url)
  end

  def extract
    FileUtils.mkdir_p(@dotnet_sdk_dir)
    raise "Extracting dotnet sdk failed" unless system("tar", "xf", @dotnet_sdk_tar, "-C", @dotnet_sdk_dir)
  end

  def retar
    @dotnet_framework_versions = Dir["#{@dotnet_sdk_dir}/shared/Microsoft.NETCore.App/*"].map{ |f| Pathname.new(f).basename.to_s }

    Dir.chdir(@dotnet_sdk_dir) do
      @dotnet_framework_versions.each do |version|
        system("tar Jcf #{dotnet_framework_tar(version)} shared/Microsoft.NETCore.App/#{version} host *.txt") or raise "Tarring the dotnet framework failed"
      end
    end
  end

  def dotnet_framework_tar(version)
    dotnet_framework_artifact_dir = File.expand_path(File.join(@buildpacks_ci_dir, '..', 'binary-builder-artifacts'))
    File.join(dotnet_framework_artifact_dir, "dotnet-framework.#{version}.linux-amd64.tar.xz")
  end

  def write_yaml
    input_dir = File.expand_path(File.join(@buildpacks_ci_dir, '..', 'dotnet-framework-built'))
    output_dir = File.expand_path(File.join(@buildpacks_ci_dir, '..', 'dotnet-framework-built-output'))
    system "rsync", "-a", "#{input_dir}/", output_dir

    framework_built_file = File.join(output_dir , 'binary-built-output', 'dotnet-framework-built.yml')
    framework_built = YAML.load_file(framework_built_file)

    Dir.chdir(output_dir) do
      GitClient.set_global_config('user.email', 'cf-ci-bot@suse.de')
      GitClient.set_global_config('user.name', 'SUSE CF CI Bot')
    end

    @dotnet_framework_versions.each do |version|
      framework_built['dotnet-framework'].push({
        'version' => version,
        'git-commit-sha' => @dotnet_sdk_git_sha,
        'timestamp' => Time.now.utc.to_s
      })

      File.write(framework_built_file, framework_built.to_yaml)

      md5sum = Digest::MD5.file(dotnet_framework_tar(version)).hexdigest
      shasum = Digest::SHA256.file(dotnet_framework_tar(version)).hexdigest

      output_file = dotnet_framework_tar(version).gsub('.tar.xz', "-#{shasum[0..7]}.tar.xz")
      FileUtils.mv(dotnet_framework_tar(version), output_file)

      git_msg = "Build dotnet-framework - #{version}\n\n"

      git_yaml = {
        'filename' => File.basename(output_file),
        'version' => version,
        'md5' => md5sum,
        'sha256' => shasum,
        'source url' => @dotnet_sdk_source_url,
        'source git-commit-sha' => @dotnet_sdk_git_sha
      }

      git_msg += git_yaml.to_yaml

      Dir.chdir(output_dir) do
        GitClient.add_file(framework_built_file)
        GitClient.safe_commit(git_msg)
      end
    end
  end
end

ExtractDotnetFramework.new(buildpacks_ci_dir).run
