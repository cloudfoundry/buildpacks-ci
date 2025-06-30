require 'json'
require 'yaml'
require 'open-uri'
require 'pathname'
require 'digest'
require 'net/http'
require 'tmpdir'
require 'English'
require 'open3'
require_relative 'php_extensions/extensions_helper'
require_relative 'binary_builder_wrapper'

module HTTPHelper
  class << self
    def download_with_follow_redirects(uri)
      uri = URI(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |httpRequest|
        response = httpRequest.request_get(uri)
        if response.is_a?(Net::HTTPRedirection)
          download_with_follow_redirects(response['location'])
        else
          response
        end
      end
    end

    def download(source_input, filename)
      uri = URI.parse(source_input.url)
      puts "Downloading #{uri} to #{filename}"
      response = download_with_follow_redirects(uri)
      if response.code == '200'
        Sha.verify_digest(response.body, source_input)
        File.write(filename, response.body)
      else
        str = "Failed to download #{uri} with code #{response.code} error: \n#{response.body}"
        raise str
      end
    end

    def download_url(url, source_input, filename)
      uri = URI.parse(url)
      response = download_with_follow_redirects(uri)
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

module DependencyBuildHelper
  class << self
    def setup_ruby
      puts "Updating ruby because bundler 2.6.2+ requires newer ruby than what comes from the default jammy ubuntu repo."
      Runner.run('mkdir', '/opt/ruby')
      # From https://github.com/cloudfoundry/ruby-buildpack/blob/v1.10.21/manifest.yml#L165
      Runner.run('curl', '-L', '-o', '/opt/ruby/ruby3.3.6.tgz', 'https://buildpacks.cloudfoundry.org/dependencies/ruby/ruby_3.3.6_linux_x64_cflinuxfs4_e4311262.tgz')
      Runner.run('tar' ,'-xzf', '/opt/ruby/ruby3.3.6.tgz', '-C', '/opt/ruby')
      ENV["PATH"] = "/opt/ruby/bin:" + ENV["PATH"]
      Runner.run('ruby', '--version')
      # update Gemfile{,.lock} to the same ruby version
      Dir.chdir("binary-builder/cflinuxfs4") do
        Runner.run("sed", "-i", "s/^ruby .*/ruby '3.3.6'/", "Gemfile")
        puts("[DEBUG] running bundle install")
        Runner.run("bundle", "install")
        puts("[DEBUG] finished bundle install")
      end
    end

    def build_nginx_helper(source_input, custom_options, static = false)
      public_gpg_key_urls = [
        "http://nginx.org/keys/maxim.key", # Maxim Konovalov’s PGP public key
        "http://nginx.org/keys/arut.key", # Roman Arutyunyan's PGP public key
        "https://nginx.org/keys/pluknet.key", # Sergey Kandaurov’s PGP public key
        "http://nginx.org/keys/sb.key", # Sergey Budnevitch’s PGP public key
        "http://nginx.org/keys/thresh.key", # Konstantin Pavlov’s PGP public key
        "https://nginx.org/keys/nginx_signing.key", # nginx public key
      ]
      GPGHelper.verify_gpg_signature(source_input.url, "#{source_input.url}.asc", public_gpg_key_urls)

      artifacts = "#{Dir.pwd}/artifacts"
      destdir = Dir.mktmpdir
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          Runner.run('wget', source_input.url)
          Runner.run('tar', 'xf', "nginx-#{source_input.version}.tar.gz")
          base_nginx_options = %w[--prefix=/ --error-log-path=stderr --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module --without-http_uwsgi_module --without-http_scgi_module --with-pcre --with-pcre-jit --with-debug]

          Dir.chdir("nginx-#{source_input.version}") do
            options = ['./configure'] + base_nginx_options + custom_options
            Runner.run(*options)
            Runner.run('make')
            system({ 'DEBIAN_FRONTEND' => 'noninteractive', 'DESTDIR' => "#{destdir}/nginx" }, 'make install')
            raise 'Could not run make install' unless $CHILD_STATUS.success?

            Dir.chdir(destdir) do
              Runner.run('rm', '-Rf', './nginx/html', './nginx/conf')
              Runner.run('mkdir', 'nginx/conf')
              if static
                Runner.run('tar', 'zcvf', "#{artifacts}/nginx-#{source_input.version}.tgz", 'nginx')
              else
                Runner.run('tar', 'zcvf', "#{artifacts}/nginx-#{source_input.version}.tgz", '.')
              end
            end
          end
        end
      end
    end

    # handle PHP extension file logic
    # returns the path to the final extension file and an instance of PHPExtensionsHelper
    def get_php_extensions(source_input, php_extensions_dir)
      major_version, minor_version, patch_version = source_input.version.split(".")
      base_extensions_file = File.join(php_extensions_dir, "php#{major_version}-base-extensions.yml")

      if !File.exist?(base_extensions_file)
        raise "No base extension file named #{base_extensions_file}, you may need to add a new file for the major version #{major_version}"
      end

      php_extensions_helper = PHPExtensionsHelper.new(base_extensions_file)

      patch_file = File.join(php_extensions_dir, "php#{major_version}#{minor_version}-extensions-patch.yml")
      if !File.exist?(patch_file)
        raise "No patch extension file named #{patch_file}, you may need to add a new file for the version line #{major_version}.#{minor_version}"
      end

      php_extensions_helper.patch!(patch_file)
      output_yml = File.join(php_extensions_dir, 'php-final-extensions.yml')
      php_extensions_helper.write_yml(output_yml)

      return output_yml, php_extensions_helper
    end

    def build_r_helper(source_input, forecast_input, plumber_input, rserve_input, shiny_input)
      artifacts = "#{Dir.pwd}/artifacts"
      source_sha = ''
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          Runner.run('mkdir', '-p', '/usr/share/man/man1')

          Runner.run('apt', 'update')

          stack = ENV.fetch('STACK')
          Runner.run('apt-get', 'install', '-y', 'gfortran', 'libbz2-dev', 'liblzma-dev', 'libpcre++-dev', 'libpcre2-dev', 'libcurl4-openssl-dev', 'libsodium-dev', 'libharfbuzz-dev', 'libfribidi-dev', 'default-jre', 'libgfortran-12-dev')

          Runner.run('wget', source_input.url)
          source_sha = Digest::SHA256.hexdigest(open("R-#{source_input.version}.tar.gz").read)
          Runner.run('tar', 'xf', "R-#{source_input.version}.tar.gz")

          Dir.chdir("R-#{source_input.version}") do
            Runner.run('./configure', '--with-readline=no', '--with-x=no', '--enable-R-shlib')
            Runner.run('make')
            Runner.run('make install')

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "install.packages('remotes', repos='https://cran.r-project.org')")

            rserve_version = rserve_input.split(".")[0..1].join(".") + "-" + rserve_input.split(".")[2..-1].join(".")

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('remotes'); remotes::install_version('Rserve', '#{rserve_version}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('remotes'); remotes::install_version('forecast', '#{forecast_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('remotes'); remotes::install_version('shiny', '#{shiny_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('remotes'); remotes::install_version('plumber', '#{plumber_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', 'remove.packages("remotes")')

            Dir.chdir('/usr/local/lib/R') do
              Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-11', './bin/gfortran')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/f951', './bin/f951')
              Runner.run('ln', '-s', './gfortran', './bin/f95')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libcaf_single.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libgfortran.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/11/libgfortran.so', './lib')
              Runner.run('cp', '-L', '/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0', './lib')
              Runner.run('tar', 'zcvf', "#{artifacts}/r-v#{source_input.version}.tgz", '.')
            end
          end
        end
      end
      source_sha
    end
  end
end

module GPGHelper
  class << self
    def verify_gpg_signature(file_url, signature_url, public_key_url)

      ## Check if gpg package is installed
      unless system('which gpg > /dev/null')
        Runner.run('apt-get', 'update')
        Runner.run('apt-get', 'install', '-y', 'gpg')
      end

      ## Verify gpg signature
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          if public_key_url.is_a?(Array)
            public_key_url.each do |key_url|
              Runner.run('wget', key_url)
              Runner.run('gpg', '--import', File.basename(key_url))
            end
          else
            Runner.run('wget', public_key_url)
          end
          Runner.run('wget', file_url)
          Runner.run('wget', signature_url)
          Runner.run('gpg', '--verify', File.basename(signature_url), File.basename(file_url))
        end
      end
    end
  end
end

class DependencyBuild
  ## Constructor ##
  def initialize(source_input, out_data, binary_builder, artifact_output, stack, php_extensions_dir = nil)
    @source_input = source_input
    @out_data = out_data
    @binary_builder = binary_builder
    @artifact_output = artifact_output
    @stack = stack
    @filename_prefix = "#{@source_input.name}_#{@source_input.version}"
    @php_extensions_dir = php_extensions_dir
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

  # this code is doing nothing except generating a buildpacks-ci-robot metadata
  # entry so our buildpacks get auto-updated.
  # TODO: check how we should handle agent dependencies in general (appdynamics vs newrelic)
  def build_appdynamics
    old_filepath = "source/appdynamics-php-agent-linux_x64-#{@source_input.version}.tar.bz2"
    filename_prefix = "#{@filename_prefix}_linux_noarch_any-stack"

    if File.exist?(old_filepath)
      merge_out_data(old_filepath, filename_prefix)
    else
      HTTPHelper.download(@source_input, old_filepath)
      @out_data[:sha256] = Sha.get_digest(old_filepath, "sha256")
      @out_data[:url] = @source_input.url
    end
  end

  def build_bower
    old_filepath = 'artifacts/temp_file.tgz'
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"
    HTTPHelper.download(@source_input, old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_bundler
    DependencyBuildHelper.setup_ruby
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-#{@source_input.version}.tgz"
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_composer
    old_filepath = "source/composer.phar"
    filename_prefix = "#{@filename_prefix}_linux_noarch_any-stack"

    if File.exist?(old_filepath)
      merge_out_data(old_filepath, filename_prefix)
    else
      HTTPHelper.download(@source_input, old_filepath)
      @out_data[:sha256] = Sha.get_digest(old_filepath, "sha256")
      @out_data[:url] = @source_input.url
    end
  end

  def build_dep
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-v#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"

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

  def build_glide
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-v#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_go
    @source_input.version = @source_input.version.delete_prefix('go')
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/go#{@source_input.version}.linux-amd64.tar.gz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    Archive.strip_top_level_directory_from_tar(old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_godep
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-v#{@source_input.version}-linux-x64.tgz"
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

  def build_jruby
    if /9.3.*/ =~ @source_input.version
      # jruby 9.3.X.X will implement ruby 2.6.X
      ruby_version = '2.6'
    elsif /9.4.*/ =~ @source_input.version
      # jruby 9.4.X.X will implement ruby 3.1.X
      ruby_version = '3.1'
    else
      raise "Unsupported jruby version line #{@source_input.version}"
    end

    full_version = "#{@source_input.version}-ruby-#{ruby_version}"
    @binary_builder.build(
      SourceInput.new(
        @source_input.name,
        @source_input.url,
        full_version,
        @source_input.md5,
        @source_input.sha256,
        @source_input.git_commit_sha
      )
    )

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-#{full_version}-linux-x64.tgz"
    filename_prefix = "#{@source_input.name}_#{full_version}_linux_x64_#{@stack}"
    Archive.strip_incorrect_words_yaml_from_tar(old_filepath)

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

  def build_miniconda
    content = HTTPHelper.read_file(@source_input.url)
    Sha.verify_digest(content, @source_input)
    sha256 = Sha.get_digest(content, 'sha256')
    @out_data[:url] = @source_input.url
    @out_data[:sha256] = sha256
  end

  def build_node
    # See https://github.com/nodejs/node/blob/main/BUILDING.md
    # for python and gcc needs for node versions.
    Utils.setup_python_and_pip
    Utils.setup_gcc

    @source_input.version = @source_input.version.delete_prefix('v')
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/#{@source_input.name}-#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    Archive.strip_top_level_directory_from_tar(old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_php
    extensionsFile, php_extensions_helper = DependencyBuildHelper.get_php_extensions(@source_input, @php_extensions_dir)
    @binary_builder.build(@source_input, "--php-extensions-file=#{extensionsFile}")

    old_filepath = "#{@binary_builder.base_dir}/php-#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"

    Archive.strip_top_level_directory_from_tar(old_filepath)
    merge_out_data(old_filepath, filename_prefix)

    @out_data[:sub_dependencies] = {}
    extensions = [php_extensions_helper.base_yml['native_modules'], php_extensions_helper.base_yml['extensions']].flatten
    extensions.sort_by { |e| e['name'].downcase }.each do |extension|
      @out_data[:sub_dependencies][extension['name'].to_sym] = { version: extension['version'] }
    end
  end

  def build_pip
    # final resting place for pip source and dependencies
    old_filepath = "/tmp/pip-#{@source_input.version}.tgz"
    ENV['LC_CTYPE'] = 'en_US.UTF-8'

    Utils.setup_python_and_pip

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', "pip==#{@source_input.version}")
        HTTPHelper.download(@source_input, old_filepath)

        Archive.strip_top_level_directory_from_tar("pip-#{@source_input.version}.tar.gz")
        Runner.run('tar', 'zxf', "pip-#{@source_input.version}.tar.gz")
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'setuptools==62.1.0')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'wheel')
        Runner.run('tar', 'zcvf', old_filepath, '.')
      end
    end

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_pipenv
    old_file_path = "/tmp/pipenv-v#{@source_input.version}.tgz"
    ENV['LC_CTYPE'] = 'en_US.UTF-8'

    Utils.setup_python_and_pip

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('/usr/bin/pip3', 'download', '--no-cache-dir', '--no-binary', ':all:', "pipenv==#{@source_input.version}")
        old_filepath = "pipenv-#{@source_input.version}.tar.gz"
        HTTPHelper.download(@source_input, old_filepath)

        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'pytest-runner')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'setuptools_scm')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'parver')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'wheel')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'invoke')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'flit_core')
        Runner.run('/usr/bin/pip3', 'download', '--no-binary', ':all:', 'hatch-vcs')
        Runner.run('tar', 'zcvf', old_file_path, '.')
      end
    end

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"
    merge_out_data(old_file_path, filename_prefix)
  end

  def build_python
    artifacts = "#{Dir.pwd}/artifacts"
    tar_path = "#{Dir.pwd}/source/Python-#{@source_input.version}.tgz"
    destdir = Dir.mktmpdir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        unless File.exist?(tar_path)
          download_path = "#{Dir.pwd}/Python-#{@source_input.version}.tgz"
          HTTPHelper.download(@source_input, download_path)
          tar_path = "Python-#{@source_input.version}.tgz"
        end

        Runner.run('tar', 'xf', tar_path)

        # Python specific configuration here
        Dir.chdir("Python-#{@source_input.version}") do

          options = [
            './configure',
            '--enable-shared',
            '--with-ensurepip=yes',
            '--with-dbmliborder=bdb:gdbm',
            '--with-tcltk-includes="-I/usr/include/tcl8.6"',
            '--with-tcltk-libs="-L/usr/lib/x86_64-linux-gnu -ltcl8.6 -L/usr/lib/x86_64-linux-gnu -ltk8.6"',
            "--prefix=#{destdir}",
            '--enable-unicode=ucs4'
          ]

          Runner.run(*options)
          packages = %w[libdb-dev libgdbm-dev tk8.6-dev]
          # install apt packages
          STDOUT.print "Running 'install dependencies' for #{@name} #{@version}... "
          Runner.run("sudo apt-get update && sudo apt-get -y install " + packages.join(' '))

          Runner.run('apt-get -y --force-yes -d install --reinstall libtcl8.6 libtk8.6 libxss1')

          FileUtils.mkdir_p destdir
          Dir.glob('/var/cache/apt/archives/lib{tcl8.6,tk8.6,xss1}_*.deb').each do |path|
            STDOUT.puts("dpkg -x #{path} #{destdir}")
            Runner.run("dpkg -x #{path} #{destdir}")
          end

          Runner.run("make")
          Runner.run("make install")
          # create python symlink
          unless File.exist?("#{destdir}/bin/python")
            File.symlink('./python3', "#{destdir}/bin/python")
          end
          raise 'Could not run make install' unless $CHILD_STATUS.success?
          Dir.chdir(destdir) do
            Runner.run('tar', 'zcvf', "#{artifacts}/python-#{@source_input.version}.tgz", '.', '--hard-dereference')
          end
        end
      end
    end

    old_file_path = "artifacts/python-#{@source_input.version}.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_file_path, filename_prefix)
  end

  def build_r
    forecast_input = SourceInput.from_file("#{Dir.pwd}/source-forecast-latest/data.json")
    plumber_input = SourceInput.from_file("#{Dir.pwd}/source-plumber-latest/data.json")
    rserve_input = SourceInput.from_file("#{Dir.pwd}/source-rserve-latest/data.json")
    shiny_input = SourceInput.from_file("#{Dir.pwd}/source-shiny-latest/data.json")

    source_sha = DependencyBuildHelper.build_r_helper(@source_input, forecast_input.version, plumber_input.version, rserve_input.version, shiny_input.version)

    old_filepath = "artifacts/#{@source_input.name}-v#{@source_input.version}.tgz"
    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)

    @out_data[:git_commit_sha] = source_sha

    @out_data[:sub_dependencies] = {}
    [forecast_input, plumber_input, rserve_input, shiny_input].each do |sub_dep|
      @out_data[:sub_dependencies][sub_dep.name.to_sym] = { source: { url: sub_dep.url, sha256: sub_dep.sha_from_url() }, version: sub_dep.version }
    end
  end

  def build_ruby
    @binary_builder.build(@source_input)

    old_filepath = "#{@binary_builder.base_dir}/ruby-#{@source_input.version}-linux-x64.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    Archive.strip_incorrect_words_yaml_from_tar(old_filepath)

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_rubygems
    old_filepath = 'artifacts/temp_file.tgz'
    HTTPHelper.download(@source_input, old_filepath)

    Archive.strip_top_level_directory_from_tar(old_filepath)

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_setuptools
    old_filepath = 'artifacts/temp_' + "#{@source_input.url}".split('/').last
    HTTPHelper.download(@source_input, old_filepath)

    if "#{@source_input.url}".end_with?(".tar.gz", ".tgz")
      Archive.strip_top_level_directory_from_tar(old_filepath)
    else
      Archive.strip_top_level_directory_from_zip(old_filepath, Dir.pwd)
    end

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_yarn
    @source_input.version = @source_input.version.delete_prefix('v')

    old_filepath = 'artifacts/temp_file.tgz'
    HTTPHelper.download(@source_input, old_filepath)

    Archive.strip_top_level_directory_from_tar(old_filepath)

    filename_prefix = "#{@filename_prefix}_linux_noarch_#{@stack}"

    merge_out_data(old_filepath, filename_prefix)
  end

  def build_nginx

    nginx_options = [
      '--with-cc-opt=-fPIC -pie',
      '--with-ld-opt=-fPIC -pie -z now',
      '--with-compat',
      '--with-mail=dynamic',
      '--with-mail_ssl_module',
      '--with-stream=dynamic',
      '--with-http_sub_module',
    ]

    DependencyBuildHelper.build_nginx_helper(@source_input, nginx_options)

    old_filepath = "artifacts/#{@source_input.name}-#{@source_input.version}.tgz"
    Archive.strip_top_level_directory_from_tar(old_filepath)
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)
  end

  def build_nginx_static

    nginx_static_options = [
      '--with-cc-opt=-fPIE -pie',
      '--with-ld-opt=-fPIE -pie -z now',
    ]

    DependencyBuildHelper.build_nginx_helper(@source_input, nginx_static_options, true)

    old_filepath = "artifacts/nginx-#{@source_input.version}.tgz"
    Archive.strip_top_level_directory_from_tar(old_filepath)
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)

  end

  def build_openresty
    artifacts = "#{Dir.pwd}/artifacts"
    destdir = Dir.mktmpdir

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('wget', @source_input.url)
        # TODO validate pgp
        Runner.run('tar', 'xf', "#{@source_input.name}-#{@source_input.version}.tar.gz")
        Dir.chdir("#{@source_input.name}-#{@source_input.version}") do
          Runner.run(
            './configure',
            "--prefix=#{destdir}/openresty",
            '-j2',
            '--error-log-path=stderr',
            '--with-http_ssl_module',
            '--with-http_v2_module',
            '--with-http_realip_module',
            '--with-http_gunzip_module',
            '--with-http_gzip_static_module',
            '--with-http_auth_request_module',
            '--with-http_random_index_module',
            '--with-http_secure_link_module',
            '--with-http_stub_status_module',
            '--without-http_uwsgi_module',
            '--without-http_scgi_module',
            '--with-pcre',
            '--with-pcre-jit',
            '--with-cc-opt=-fPIC -pie',
            '--with-ld-opt=-fPIC -pie -z now',
            '--with-compat',
            '--with-mail=dynamic',
            '--with-mail_ssl_module',
            '--with-stream=dynamic',
          )
          Runner.run('make', '-j2')
          system({ 'DEBIAN_FRONTEND' => 'noninteractive' }, 'make install')
          raise 'Could not run make install' unless $CHILD_STATUS.success?

          Dir.chdir("#{destdir}/openresty") do
            Runner.run('rm', '-Rf', './nginx/html', './nginx/conf')
            Runner.run('mkdir', './nginx/conf')
            Runner.run('rm', './bin/openresty')
            Runner.run('tar', 'zcvf', "#{artifacts}/openresty-#{@source_input.version}.tgz", '.')
          end
        end
      end
    end

    old_filepath = "artifacts/#{@source_input.name}-#{@source_input.version}.tgz"
    filename_prefix = "#{@filename_prefix}_linux_x64_#{@stack}"
    merge_out_data(old_filepath, filename_prefix)
  end

  class Utils

    def self.setup_python_and_pip
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'python3', 'python3-pip')
      Runner.run('pip3', 'install', '--upgrade', 'pip', 'setuptools')
    end

    def self.setup_gcc
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'software-properties-common')
      Runner.run('add-apt-repository', '-y', 'ppa:ubuntu-toolchain-r/test')
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'gcc-12', 'g++-12')
      Runner.run('update-alternatives', '--install', '/usr/bin/gcc', 'gcc', '/usr/bin/gcc-12', '60', '--slave', '/usr/bin/g++', 'g++', '/usr/bin/g++-12')
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
  def execute(binary_builder, stack, source_input, build_input, build_output, artifact_output, dep_metadata_output, php_extensions_dir, skip_commit = false)

    build_input.copy_to_build_output unless skip_commit

    out_data = {
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

    DependencyBuild.new(source_input, out_data, binary_builder, artifact_output, stack, php_extensions_dir).build

    unless skip_commit
      build_output.add_output("#{source_input.version}-#{stack}.json", out_data)
      build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack}")
    end

    dep_metadata_output.write_metadata(out_data[:url], out_data)

    out_data
  end
end
