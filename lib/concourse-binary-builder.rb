require 'yaml'
require 'digest'
require 'fileutils'
require_relative 'git-client'

class ConcourseBinaryBuilder

  attr_reader :binary_name, :git_ssh_key, :task_root_dir
  attr_reader :binary_builder_dir, :built_dir, :builds_dir
  attr_reader :builds_yaml_artifacts, :binary_artifacts_dir, :original_source_code_dir, :source_url
  attr_reader :verification_type, :verification_value, :flags, :latest_build, :remaining_builds
  attr_reader :platform, :os_name

  def initialize(binary_name, task_root_dir, git_ssh_key, platform, os_name)
    @platform = platform.to_sym
    @os_name = os_name.to_sym
    @git_ssh_key = git_ssh_key
    @binary_name = binary_name
    @task_root_dir = task_root_dir
    @binary_builder_dir = File.join(task_root_dir,'binary-builder')
    @built_dir = File.join(task_root_dir, 'built-yaml')
    @builds_dir = File.join(task_root_dir ,'builds-yaml')
    @builds_yaml_artifacts = File.join(task_root_dir, 'builds-yaml-artifacts')
    @binary_artifacts_dir = File.join(task_root_dir, 'binary-builder-artifacts')
    @original_source_code_dir = File.join(binary_artifacts_dir, 'original-source-code')
    FileUtils.mkdir_p(original_source_code_dir)
  end

  def run
    load_builds_yaml

    unless latest_build
      puts "There are no new builds for #{binary_name} requested."
      exit
    end

    build_dependency

    tar_dependency_source_code

    copy_binaries_to_output_directory

    git_msg = create_git_commit_msg

    commit_yaml_artifacts(git_msg)
  end

  private

  def load_builds_yaml
    builds_file = File.join(builds_dir, "#{binary_name}-builds.yml")
    builds = YAML.load_file(builds_file)

    @latest_build = builds[binary_name].shift
    @remaining_builds = builds

    return if @latest_build.nil?

    @flags = "--name=#{binary_name}"
    latest_build.each_pair do |key, value|
      if key == 'md5' || key == 'sha256'
        @verification_type = key
        @verification_value = value
      elsif key == 'gpg-signature'
        @verification_type = key
        @verification_value = "\n#{value}"
      end
      @flags << %( --#{key}="#{value}")
    end
  end

  def build_dependency
    if binary_name == "composer"
      @source_url = "https://getcomposer.org/download/#{latest_build['version']}/composer.phar"
      download_composer(source_url)
    else
      binary_builder_output = run_binary_builder(flags)
      /- url:\s(.*)$/.match(binary_builder_output)
      @source_url = $1
    end
  end

  def download_composer(url)
      system("curl #{url} -o #{binary_builder_dir}/composer-#{latest_build['version']}.phar") or raise "Could not download composer.phar"
  end

  def tar_dependency_source_code
    version_to_build = latest_build['version']

    dependency_source = case binary_name
                        when "composer" then "#{binary_builder_dir}/composer-#{version_to_build}.phar"
                        when "glide" then "src/"
                        when "godep" then "src/"
                        else source_directory
                        end

    if binary_name == "composer"
      system("tar -zcf #{binary_builder_dir}/build.tgz #{dependency_source}") or raise "Could not tar composer-#{version_to_build}.phar"
    else
      if Dir.exist?(File.join("/tmp",dependency_source))
        system("tar -zcf #{binary_builder_dir}/build.tgz -C /tmp ./#{dependency_source}") or raise "Could not create tar"
      else
        raise "Could not find original source after build"
      end
    end
  end

  def copy_binaries_to_output_directory
      FileUtils.cp_r(Dir["#{binary_builder_dir}/*.tgz", "#{binary_builder_dir}/*.tar.gz", "#{binary_builder_dir}/*.phar"], binary_artifacts_dir)
      FileUtils.cp_r("#{binary_artifacts_dir}/build.tgz", original_source_code_dir)
  end


  def create_git_commit_msg
    version_built = latest_build['version']

    ext = case binary_name
            when 'composer' then
              '*.phar'
            when 'go' then
              '*.tar.gz'
            else
              '-*.tgz'
          end

    filename = Dir["#{binary_builder_dir}/#{binary_name + ext}"].first
    filename.match /(binary-builder\/.*)/
    short_filename = $1

    md5sum = Digest::MD5.file(filename).hexdigest
    shasum = Digest::SHA256.file(filename).hexdigest

    ci_skip = remaining_builds[binary_name].empty? && !is_automated

    git_msg = "Build #{binary_name} - #{version_built}\n\nfilename: #{short_filename}, md5: #{md5sum}, sha256: #{shasum}"
    git_msg += "\n\nsource url: #{source_url}, source #{verification_type}: #{verification_value}"
    git_msg += "\n\n[ci skip]" if ci_skip
    git_msg
  end

  def dependency_version_not_built(built_versions)
    !built_versions.any? do |version_hash|
      version_hash['version'] == latest_build['version']
    end
  end

  def commit_yaml_artifacts(git_msg)
    #don't change behavior for non-automated builds
    if is_automated
      #get latest version of <binary>-built.yml
      add_ssh_key_and_update(built_dir, 'binary-built-output')
      built_file = File.join(built_dir, "#{binary_name}-built.yml")
      built = YAML.load_file(built_file)
      built_versions = built[binary_name]

      if dependency_version_not_built(built_versions)
        built[binary_name].push latest_build
        built[binary_name][-1]["timestamp"] = Time.now.utc.to_s

        File.write(built_file, built.to_yaml)
      end
      commit_and_rsync(built_dir, builds_yaml_artifacts, git_msg, built_file)
    else
      builds_file = File.join(builds_dir, "#{binary_name}-builds.yml")
      File.write(builds_file, remaining_builds.to_yaml)
      commit_and_rsync(builds_dir, builds_yaml_artifacts, git_msg, builds_file)
    end
  end

  def run_binary_builder(flags)
    output = ''

    Dir.chdir(binary_builder_dir) do
      output = `./bin/binary-builder #{flags}`
      raise "Could not build" unless $?.success?
    end

    output
  end

  def add_ssh_key_and_update(dir, branch)
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
    git checkout #{branch}
    git pull -r
    HEREDOC
  end

  def is_automated
    automated = %w(composer godep glide nginx node)
    automated.include? binary_name
  end

  def commit_and_rsync(in_dir, out_dir, git_msg, file)

    Dir.chdir(in_dir) do

      GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
      GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')
      GitClient.add_file(file)
      GitClient.safe_commit(git_msg)

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
