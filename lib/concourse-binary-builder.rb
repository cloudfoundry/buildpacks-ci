require 'yaml'
require 'digest'
require 'fileutils'
require_relative 'git-client'

class ConcourseBinaryBuilder

  attr_reader :dependency, :git_ssh_key, :task_root_dir
  attr_reader :binary_builder_dir, :built_dir, :builds_dir
  attr_reader :builds_yaml_artifacts, :binary_artifacts_dir, :source_url
  attr_reader :verification_type, :verification_value, :flags, :latest_build, :remaining_builds
  attr_reader :platform, :os_name

  def initialize(dependency, task_root_dir, git_ssh_key, platform, os_name)
    @platform = platform.to_sym
    @os_name = os_name.to_sym
    @git_ssh_key = git_ssh_key
    @dependency = dependency
    @task_root_dir = task_root_dir
    @binary_builder_dir = File.join(task_root_dir,'binary-builder')
    @built_dir = File.join(task_root_dir, 'built-yaml')
    @builds_dir = File.join(task_root_dir,'builds-yaml')
    @builds_yaml_artifacts = File.join(task_root_dir, 'builds-yaml-artifacts')
    @binary_artifacts_dir = File.join(task_root_dir, 'binary-builder-artifacts')
    @source_artifacts_dir = File.join(task_root_dir, 'source-artifacts')
  end

  def run
    load_builds_yaml

    unless latest_build
      puts "There are no new builds for #{dependency} requested."
      exit
    end

    build_dependency

    convert_gz_to_xz

    add_checksum_to_binary_name

    copy_binaries_to_output_directory

    create_git_commit_msg

    commit_yaml_artifacts
  end

  private

  def load_builds_yaml
    builds_file = File.join(builds_dir, 'binary-builds', "#{dependency}-builds.yml")
    builds = YAML.load_file(builds_file)

    @latest_build = builds[dependency].shift
    @remaining_builds = builds

    return if @latest_build.nil?

    @flags = "--name=#{dependency}"
    export_dir = File.join(@source_artifacts_dir, "#{dependency}-#{latest_build['version']}")
    @flags << " --sources-export-dir=#{export_dir}"
    latest_build.each_pair do |key, value|
      if key == 'md5' || key == 'sha256' || key == 'git-commit-sha'
        @verification_type = key
        @verification_value = value
      elsif key == 'gpg-signature'
        @verification_type = key
        @verification_value = "\n#{value}"
      end
      @flags << %( --#{key}="#{value}")
    end

    if %w(php php7).include? dependency
      extension_file = File.join(builds_dir, 'binary-builds', "#{dependency}-extensions.yml")
      if latest_build['version'].start_with?('7.2.')
        extension_file = File.join(builds_dir, 'binary-builds', "#{dependency}2-extensions.yml")
      end
      @flags << " --php-extensions-file=#{extension_file}"
    end
  end

  def build_dependency
    case dependency
    when 'bower'
      @source_url = "https://registry.npmjs.org/bower/-/bower-#{latest_build['version']}.tgz"
      output_file = "bower-#{latest_build['version']}.tgz"
      download_non_build_dependency(source_url, output_file)
    when 'composer'
      @source_url = "https://getcomposer.org/download/#{latest_build['version']}/composer.phar"
      output_file = "composer-#{latest_build['version']}.phar"
      download_non_build_dependency(source_url, output_file)
    when 'yarn'
      @source_url = "https://yarnpkg.com/downloads/#{latest_build['version']}/yarn-v#{latest_build['version']}.tar.gz"
      output_file = "yarn-v#{latest_build['version']}.tar.gz"
      download_non_build_dependency(source_url, output_file)
    else
      binary_builder_output = run_binary_builder(flags)
      /^Source URL:\s(.*)$/.match(binary_builder_output)
      @source_url = $1
    end
  end

  def download_non_build_dependency(url, output_filename)
    output_file = "#{binary_builder_dir}/#{output_filename}"

    system("curl -L #{url} -o #{output_file}") or raise "Could not download #{url}"

    downloaded_file_hash = ""

    if @verifcation_type == 'md5'
      downloaded_file_hash = Digest::MD5.file(output_file).hexdigest
    elsif @verification_type == 'sha256'
      downloaded_file_hash = Digest::SHA256.file(output_file).hexdigest
    else
      raise "Unknown verification type: #{@verification_type}"
    end

    if @verification_value != downloaded_file_hash
      raise "#{@verification_type} verification failed: expected #{@verification_value}, got #{downloaded_file_hash}"
    end
  end

  def convert_gz_to_xz
    return unless dependency == 'dotnet'

    filename = Dir["#{binary_builder_dir}/#{dependency}*.tar.gz"].first
    system('gunzip', filename) or raise "Could not gunzip #{filename}"
    filename.gsub!(/\.gz$/, '')
    system('xz', filename) or raise "Could not xz #{filename}"
  end

  def add_checksum_to_binary_name
    Dir["#{binary_builder_dir}/*.{tgz,tar.gz,tar.xz,phar,zip}"].each do |name|
      prefix,suffix = /(.*)(\.tgz|\.tar\.gz|\.tar\.xz|\.phar|\.zip)$/.match(name)[1,2]
      sha256sum = Digest::SHA256.file(name).hexdigest[0..7]
      FileUtils.mv(name, "#{prefix}-#{sha256sum}#{suffix}")
    end
  end

  def copy_binaries_to_output_directory
    FileUtils.cp_r(Dir["#{binary_builder_dir}/*.{tgz,tar.gz,tar.xz,phar,zip}"], binary_artifacts_dir)
  end

  def create_git_commit_msg
    version_built = latest_build['version']

    ext = case dependency
            when 'composer' then
              '*.phar'
            when 'go', 'yarn' then
              '*.tar.gz'
            when 'dotnet' then
              '*.tar.xz'
            when 'hwc' then
              '*.zip'
            else
              '-*.tgz'
          end

    filename = Dir["#{binary_builder_dir}/#{dependency + ext}"].first
    short_filename = File.basename(filename)
    md5sum = Digest::MD5.file(filename).hexdigest
    shasum = Digest::SHA256.file(filename).hexdigest

    ci_skip = remaining_builds[dependency].empty? && !is_automated

    @git_msg = "Build #{dependency} - #{version_built}\n\n"

    @build_output_info = {
      "filename" => short_filename,
      'version' => version_built,
      'md5' => md5sum,
      'sha256' => shasum,
      'source url' => source_url,
      "source #{verification_type}" => verification_value
    }

    @git_msg += @build_output_info.to_yaml

    @git_msg += "\n\n[ci skip]" if ci_skip
  end

  def dependency_version_not_built(built_versions)
    !built_versions.any? do |version_hash|
      version_hash['version'] == @build_output_info['version'] &&
      version_hash['sha256'] == @build_output_info['sha256']
    end
  end

  def commit_yaml_artifacts
    #don't change behavior for non-automated builds
    if is_automated
      #get latest version of <binary>-built.yml
      add_ssh_key_and_update(built_dir)
      built_file = File.join(built_dir, 'binary-built-output' ,"#{dependency}-built.yml")
      built = YAML.load_file(built_file)
      built_versions = built[dependency]

      if dependency_version_not_built(built_versions)
        built[dependency].push latest_build
        built[dependency][-1]["timestamp"] = Time.now.utc.to_s

        File.write(built_file, built.to_yaml)
      end
      commit_and_rsync(built_dir, builds_yaml_artifacts, built_file)
    else
      builds_file = File.join(builds_dir, 'binary-builds', "#{dependency}-builds.yml")
      File.write(builds_file, remaining_builds.to_yaml)
      commit_and_rsync(builds_dir, builds_yaml_artifacts, builds_file)
    end
  end

  def run_binary_builder(flags)
    output = ''

    Dir.chdir(binary_builder_dir) do
      output = `./bin/binary-builder #{flags}`
      unless $?.success?
        puts output
        raise "Could not build"
      end
    end

    output
  end

  def add_ssh_key_and_update(dir)
    File.write("/tmp/git_ssh_key", git_ssh_key)
    system(<<-HEREDOC)
    eval "$(ssh-agent)"
    mkdir -p ~/.ssh
    ssh-keyscan -t rsa github.com > ~/.ssh/known_hosts

    set +x
    chmod 600 /tmp/git_ssh_key
    ssh-add -D
    ssh-add /tmp/git_ssh_key
    set -x
    cd #{dir}
    git pull -r
    HEREDOC
  end

  def is_automated
    automated = %w(bower bundler composer dotnet godep dep glide hwc nginx node yarn)
    automated.include? dependency
  end

  def commit_and_rsync(in_dir, out_dir, file)

    Dir.chdir(in_dir) do

      GitClient.set_global_config('user.email', 'cf-ci-bot@suse.de')
      GitClient.set_global_config('user.name', 'SUSE CF CI Server')
      GitClient.add_file(file)
      GitClient.safe_commit(@git_msg)

      system("rsync -a #{in_dir}/ #{out_dir}")
    end
  end

  # given a platform architecture (e.g. output of `uname -m`) and an
  # os name (e.g. output of `uname -o`), output the name of the
  # directory binary-builder places the source it uses to
  # build the dependency

  def source_directory
    platform_map = { 'x86_64':  'x86_64',
                     'ppc64le': 'powerpc64le'}

    os_name_map = {'GNU/Linux': 'linux-gnu'}


    "#{platform_map[platform]}-#{os_name_map[os_name]}/"
  end


end
