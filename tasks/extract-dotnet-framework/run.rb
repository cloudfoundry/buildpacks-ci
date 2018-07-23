#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'
require 'digest'


buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

source_file = JSON.parse(open('source/data.json').read)
source_version = source_file.dig('version', 'ref')
stack = ENV['STACK']
build_file = JSON.parse(open("builds/binary-builds-new/dotnet/#{source_version}-#{stack}.json").read)
dotnet_sdk_dependency_url = build_file['url']
git_commit_sha = build_file.dig('git_commit_sha')
sdk_source_url = build_file.dig('source', 'url')
sdk_version = build_file['version']
tracker_story_id = build_file['tracker_story_id']

class ExtractDotnetFramework
  def initialize(
      buildpacks_ci_dir,
      sdk_version,
      dotnet_sdk_dependency_url,
      git_commit_sha,
      sdk_source_url,
      tracker_story_id,
      stack
  )
    @buildpacks_ci_dir = buildpacks_ci_dir
    @sdk_version = sdk_version
    @dotnet_sdk_dependency_url = dotnet_sdk_dependency_url
    @dotnet_sdk_git_sha = git_commit_sha
    @dotnet_sdk_source_url = sdk_source_url

    @dotnet_sdk_tar = File.join("/tmp", "dotnet_sdk.tar.xz")
    @dotnet_sdk_dir = File.join("/tmp", "dotnet_sdk")
    @tracker_story_id = tracker_story_id

    @stack = stack
  end

  def run
    download
    extract
    retar
    write_yaml
  end

  private

  def download
    raise "Downloading dotnet sdk tar failed" unless system("curl", "-o", @dotnet_sdk_tar, @dotnet_sdk_dependency_url)
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
    File.join(@buildpacks_ci_dir, '..', 'binary-builder-artifacts', "dotnet-framework.#{version}.linux-amd64.tar.xz")
  end

  def write_yaml
    input_dir = File.expand_path('builds')
    output_dir = File.expand_path('builds-artifacts')
    system "rsync", "-a", "#{input_dir}/", output_dir


    Dir.chdir(output_dir) do
      GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
      GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')
    end

    @dotnet_framework_versions.each do |version|
      framework_build_file = File.join(output_dir, 'binary-builds-new', 'dotnet-framework', "#{version}-#{@stack}.json")

      md5sum = Digest::MD5.file(dotnet_framework_tar(version)).hexdigest
      shasum = Digest::SHA256.file(dotnet_framework_tar(version)).hexdigest

      output_file = dotnet_framework_tar(version).gsub('.tar.xz', "-#{@stack}-#{shasum[0..7]}.tar.xz")
      FileUtils.mv(dotnet_framework_tar(version), output_file)

      framework_build_data = {
        'tracker_story_id' => @tracker_story_id,
        'version' => version,
        'sha256' => shasum,
        'url' => "https://buildpacks.cloudfoundry.org/dependencies/dotnet-framework/#{File.basename(output_file)}"
      }

      File.write(framework_build_file, framework_build_data.to_json)

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
        GitClient.add_file(framework_build_file)
        GitClient.safe_commit(git_msg)
      end
    end
  end
end

ExtractDotnetFramework.new(
    buildpacks_ci_dir,
    sdk_version,
    dotnet_sdk_dependency_url,
    sdk_source_url,
    git_commit_sha,
    tracker_story_id,
    stack
).run
