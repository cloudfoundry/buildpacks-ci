require 'json'
require 'yaml'
require 'open-uri'
require 'pathname'
require 'digest'
require 'net/http'
require 'tmpdir'
require 'English'
require_relative 'merge_extensions'
require_relative 'binary_builder_wrapper'

module HTTPHelper
  class << self
    def download(source_input, filename)
      uri = URI.parse(source_input.url)
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        Sha.verify_digest(response.body, source_input)
        File.write(filename, response.body)
      end
    end

    def download_url(url, source_input, filename)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        Sha.verify_digest(response.body, source_input)
        File.write(filename, response.body)
      end
    end

    def read_file(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body if response.code == '200'
    end
  end
end

module Sha
  class << self
    def verify_digest(content, source_input)
      sha1 = Digest::SHA1.hexdigest(content)
      sha256 = Digest::SHA2.new(256).hexdigest(content)
      md5 = Digest::MD5.hexdigest(content)
      if source_input.md5? && md5 != source_input.md5
        raise 'MD5 digest does not match version digest'
      elsif source_input.sha256? && sha256 != source_input.sha256
        raise 'SHA256 digest does not match version digest'
      elsif source_input.sha1? && sha1 != source_input.sha1
        raise 'SHA1 digest does not match version digest'
      end
    end

    def get_digest(content, algorithm)
      case algorithm
      when 'sha256'
        Digest::SHA2.new(256).hexdigest(content)
      when 'md5'
        Digest::MD5.hexdigest(content)
      when 'sha1'
        Digest::SHA1.hexdigest(content)
      else
        raise 'Unknown digest algorithm'
      end
    end
  end
end

module Runner
  class << self
    def run(*args)
      system({ 'DEBIAN_FRONTEND' => 'noninteractive' }, *args)
      raise "Could not run #{args}" unless $CHILD_STATUS.success?
    end
  end
end

module Archive
  class << self
    def strip_top_level_directory_from_tar(filename)
      Dir.mktmpdir do |dir|
        Runner.run('tar', '-C', dir, '--transform', 's:^\./::', '--strip-components', '1', '-xf', filename)
        Runner.run('tar', '-C', dir, '-czf', filename, '.')
      end
    end

    def strip_incorrect_words_yaml_from_tar(filename)
      Dir.mktmpdir do |dir|
        Runner.run('tar', '-C', dir, '-xf', filename)
        Runner.run('find', dir, '-type', 'f', '-name', 'incorrect_words.yaml', '-delete')
        # Add recursive search and destroy in all jar files"
        search_delete_command = 'find ' + dir + ' -name "*.jar" -exec grep -l incorrect_words.yaml {} \; | xargs -I {} zip -q -d {} "*incorrect_words.yaml"'
        Runner.run('bash', '-c', search_delete_command)
        Runner.run('tar', '-C', dir, '-czf', filename, '.')
      end
    end

    def strip_top_level_directory_from_zip(filename, destination)
      Dir.mktmpdir do |dir|
        Runner.run('unzip', '-d', dir, filename)

        subdir = Dir.glob(File.join(dir, '*')).first
        Dir.chdir(subdir) do
          zip_file = File.join(destination, filename)
          File.delete(zip_file)
          Runner.run('zip', '-r', zip_file, '.')
        end
      end
    end
  end
end

class DependencyBuild
  ## Constructor ##
  def initialize(source_input, out_data, binary_builder, artifact_output, stack)
    @source_input = source_input
    @out_data = out_data
    @binary_builder = binary_builder
    @artifact_output = artifact_output
    @stack = stack
    @filename_prefix = "#{@source_input.name}_#{@source_input.version}"
  end

  def build
    if @source_input.name.include?('miniconda')
      build_miniconda
    else
      method_name = "build_#{@source_input.name.sub('-', '_')}"
      puts "Running #{method_name}"
      if respond_to?(method_name)
        public_send(method_name)
      else
        raise "No build method for #{@source_input.name}"
      end
    end
  end

  def build_cnb
    old_filepath = "artifacts/#{@source_input.name}.tgz"
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"
    cnb_name = @source_input.repo.split('/').last
    uri = "https://github.com/#{@source_input.repo}/releases/download/v#{@source_input.version}/#{cnb_name}-#{@source_input.version}.tgz"
    HTTPHelper.download_url(uri, @source_input, old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def merge_out_data(old_file_path, filename_prefix)
    @out_data.merge!(
      @artifact_output.move_dependency(
        @source_input.name,
        old_file_path,
        filename_prefix
      )
    )
  end

  #########################
  ## Dependency builders ##
  #########################

  def build_bower
    old_filepath = 'artifacts/temp_file.tgz'
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"
    HTTPHelper.download(@source_input, old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_libunwind
    built_path = File.join(Dir.pwd, 'built')
    Dir.mkdir(built_path)

    url = "#{@source_input.url}"
    file_path = url.slice((url.rindex('/') + 1)..(url.length))
    dir = file_path.delete_suffix('.tar.gz')

    Dir.chdir('source') do
      # github-releases depwatcher has already downloaded .tar.gz
      Runner.run('tar', 'zxf', "#{file_path}")
      Dir.chdir("#{dir}") do
        Runner.run('./configure', "--prefix=#{built_path}")
        Runner.run('make')
        Runner.run('make install')
      end
    end
    old_filename = "#{dir}.tgz"
    Dir.chdir(built_path) do
      Runner.run('tar', 'czf', old_filename, 'include', 'lib')
    end

    old_file_path = File.join(built_path, old_filename)
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_file_path, filename_prefix)
  end

  def build_libgdiplus
    Runner.run('apt', 'update')
    Runner.run('apt-get', 'install', '-y', 'automake', 'libtool')

    built_path = File.join(Dir.pwd, 'built')
    Dir.mkdir(built_path)

    Runner.run('git', 'clone', '--single-branch', '--branch', "#{@source_input.version}", "https://github.com/#{@source_input.repo}",
               "#{@source_input.name}-#{@source_input.version}")
    Dir.chdir("#{@source_input.name}-#{@source_input.version}") do
      ENV['CXXFLAGS'] = "-g -Wno-maybe-uninitialized"
      ENV['CFLAGS'] = "-g -Wno-maybe-uninitialized"
      Runner.run('./autogen.sh', "--prefix=#{built_path}")
      Runner.run('make')
      Runner.run('make install')
    end

    old_filename = "#{@source_input.name}-#{@source_input.version}.tgz"
    Dir.chdir(built_path) do
      Runner.run('tar', 'czf', old_filename, 'lib')
    end

    old_file_path = File.join(built_path, old_filename)
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_file_path, filename_prefix)
  end

  def build_node
    @source_input.version = @source_input.version.delete_prefix('v')
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    Archive.strip_top_level_directory_from_tar(old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_dotnet_sdk
    old_filepath = Utils.prune_dotnet_files(@source_input, ['./shared/*'], true)
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)
  end

  def build_dotnet_runtime
    old_filepath = Utils.prune_dotnet_files(@source_input, ['./dotnet'])
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)
  end

  def build_dotnet_aspnetcore
    old_filepath = Utils.prune_dotnet_files(@source_input, %w[./dotnet ./shared/Microsoft.NETCore.App])
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)
  end

  def build_httpd
    @binary_builder.build(@source_input)

    old_file_path = "#{@binary_builder.base_dir}/#{@source_input.name}-#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    Archive.strip_top_level_directory_from_tar(old_file_path)

    merge_out_data(old_file_path, filename_prefix)
  end

  def build_miniconda
    content = HTTPHelper.read_file(@source_input.url)
    Sha.verify_digest(content, @source_input)
    sha256 = Sha.get_digest(content, 'sha256')
    @out_data[:url] = @source_input.url
    @out_data[:sha256] = sha256
  end

  def bundle_pip_dependencies
    # final resting place for pip source and dependencies
    old_filepath = "/tmp/pip-#{@source_input.version}.tgz"
    ENV['LC_CTYPE'] = 'en_US.UTF-8'

    # For the latest version of pip, it requires python version >= 3.7 (ref: https://github.com/pypa/pip/pull/10641),
    # so we need to install python >= 3.7 first.
    Utils.setup_pip

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', "pip==#{@source_input.version}")
        content = File.open.read
        Sha.verify_digest(content, @source_input)

        Archive.strip_top_level_directory_from_tar("pip-#{@source_input.version}.tar.gz")
        Runner.run('tar', 'zxf', "pip-#{@source_input.version}.tar.gz")
        Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'setuptools==62.1.0')
        Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'wheel')
        Runner.run('tar', 'zcvf', old_filepath, '.')
      end
    end

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  class Utils
    def self.setup_pip
      Runner.run('curl', '-L', 'https://bootstrap.pypa.io/get-pip.py', '-o', 'get-pip.py')
      Runner.run('python3', 'get-pip.py')
      Runner.run('/usr/local/bin/pip3', 'install', '--upgrade', 'pip', 'setuptools')
      Runner.run('rm', '-f', 'get-pip.py')
    end

    def self.prune_dotnet_files(source_input, files_to_exclude, write_runtime = false)
      source_file = File.expand_path(Dir.glob('source/*.tar.gz').first)
      adjusted_file = "/tmp/#{source_input.name}.#{source_input.version}.linux-amd64.tar.xz"
      exclude_list = files_to_exclude.map { |file| "--exclude=#{file}" }.join(' ')
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          `tar -xf #{source_file} #{exclude_list}`
          write_runtime_version_file(source_file, dir) if write_runtime
          # Use xz to compress smaller than gzip
          `tar -Jcf #{adjusted_file} ./*`
        end
      end
      adjusted_file
    end

    def self.write_runtime_version_file(source_file, sdk_dir)
      Dir.chdir(sdk_dir) do
        runtime_glob = './shared/Microsoft.NETCore.App/'
        output = `tar tf #{source_file} #{runtime_glob}`
        files = output.split("\n").select { |line| line.end_with? '/' }
        version = Pathname.new(files.last).basename.to_s

        File.open('RuntimeVersion.txt', 'w') do |f|
          f.write(version)
        end
      end
    end
  end
end

class Builder
  def execute(binary_builder, stack, source_input, build_input, build_output, artifact_output, dep_metadata_output, _php_extensions_dir = __dir__, skip_commit = false)
    cnb_list = [
      'org.cloudfoundry.node-engine',
      'org.cloudfoundry.npm',
      'org.cloudfoundry.yarn-install',
      'org.cloudfoundry.nodejs-compat',
      'org.cloudfoundry.dotnet-core-runtime',
      'org.cloudfoundry.dotnet-core-aspnet',
      'org.cloudfoundry.dotnet-core-sdk',
      'org.cloudfoundry.dotnet-core-conf',
      'org.cloudfoundry.python-runtime',
      'org.cloudfoundry.pip',
      'org.cloudfoundry.pipenv',
      'org.cloudfoundry.conda',
      'org.cloudfoundry.php-dist',
      'org.cloudfoundry.php-composer',
      'org.cloudfoundry.php-compat',
      'org.cloudfoundry.httpd',
      'org.cloudfoundry.nginx',
      'org.cloudfoundry.php-web',
      'org.cloudfoundry.dotnet-core-build',
      'org.cloudfoundry.go-compiler',
      'org.cloudfoundry.go-mod',
      'org.cloudfoundry.dep',
      'org.cloudfoundry.icu'
    ]

    build_input.copy_to_build_output unless skip_commit

    out_data = {
      tracker_story_id: build_input.tracker_story_id,
      version: source_input.version,
      source: {
        url: source_input.url,
        md5: source_input.md5,
        sha256: source_input.sha256
      }
    }

    unless out_data[:source][:sha256]
      content = HTTPHelper.read_file(source_input.url)
      out_data[:source][:sha256] = Sha.get_digest(content, 'sha256')
    end

    ## Check if the source is CNB
    if cnb_list.include?(source_input.name)
      DependencyBuild.new(source_input, out_data, binary_builder, artifact_output, stack).build_cnb
    else
      DependencyBuild.new(source_input, out_data, binary_builder, artifact_output, stack).build
    end

    unless skip_commit
      build_output.add_output("#{source_input.version}-#{stack}.json", out_data)
      build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack} [##{build_input.tracker_story_id}]")
    end

    dep_metadata_output.write_metadata(out_data[:url], out_data)

    out_data
  end
end
