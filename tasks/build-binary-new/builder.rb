require 'json'
require 'yaml'
require 'open-uri'
require 'digest'
require 'net/http'
require 'tmpdir'
require_relative 'merge-extensions'


module Runner
  def run(*args)
    system({ 'DEBIAN_FRONTEND' => 'noninteractive' }, *args)
    raise "Could not run #{args}" unless $?.success?
  end
end

module DependencyBuild
  def build_pipenv(source_input)
    old_file_path = "/tmp/pipenv-v#{source_input.version}.tgz"
    Runner.run('apt', 'update')
    Runner.run('apt-get', 'install', '-y', 'python-pip', 'python-dev', 'build-essential')
    Runner.run('pip', 'install', '--upgrade', 'pip')
    Runner.run('pip', 'install', '--upgrade', 'setuptools')
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', "pipenv==#{source_input.version}")
        if Digest::MD5.hexdigest(open("pipenv-#{source_input.version}.tar.gz").read) != source_input.md5
          raise 'MD5 digest does not match version digest'
        end
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'pytest-runner')
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'setuptools_scm')
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'parver')
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'wheel')
        Runner.run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'invoke')
        Runner.run('tar', 'zcvf', old_file_path, '.')
      end
    end
    old_file_path
  end

  def build_libunwind(source_input)
    built_path = File.join(Dir.pwd, 'built')
    Dir.mkdir(built_path)

    Dir.chdir('source') do
      # github-releases depwatcher has already downloaded .tar.gz
      Runner.run('tar', 'zxf', "#{source_input.name}-#{source_input.version}.tar.gz")
      Dir.chdir("#{source_input.name}-#{source_input.version}") do
        Runner.run('./configure', "--prefix=#{built_path}")
        Runner.run('make')
        Runner.run('make install')
      end
    end
    old_filename = "#{source_input.name}-#{source_input.version}.tgz"
    Dir.chdir(built_path) do
      Runner.run('tar', 'czf', old_filename, 'include', 'lib')
    end
    File.join(built_path, old_filename)
  end

  def build_libgdiplus(source_input)
    Runner.run('apt', 'update')
    Runner.run('apt-get', 'install', '-y', 'automake', 'libtool')

    built_path = File.join(Dir.pwd, 'built')
    Dir.mkdir(built_path)

    Runner.run('wget', source_input.url, '-O', "#{source_input.version}.tar.gz")

    Dir.mkdir("#{source_input.name}-#{source_input.version}")
    Runner.run('tar', 'zxf', "#{source_input.version}.tar.gz", '-C', "#{source_input.name}-#{source_input.version}", '--strip-components', '1')
    Dir.chdir("#{source_input.name}-#{source_input.version}") do
      Runner.run('./autogen.sh', "--prefix=#{built_path}")
      Runner.run('make')
      Runner.run('make install')
    end

    old_filename = "#{source_input.name}-#{source_input.version}.tgz"
    Dir.chdir(built_path) do
      Runner.run('tar', 'czf', old_filename, 'lib')
    end
    File.join(built_path, old_filename)
  end

  def build_r(source_input, forecast_input, plumber_input, rserve_input, shiny_input)
    artifacts = "#{Dir.pwd}/artifacts"
    source_sha = ''
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('mkdir', '-p', '/usr/share/man/man1')

        Runner.run('apt', 'update')

        stack = ENV.fetch('STACK')
        fs_specific_packages = stack == 'cflinuxfs2' ? ['libgfortran-4.8-dev'] : ['libgfortran-7-dev']
        Runner.run('apt-get', 'install', '-y', 'gfortran', 'libbz2-dev', 'liblzma-dev', 'libpcre++-dev', 'libcurl4-openssl-dev', 'default-jre', *fs_specific_packages)

        Runner.run('wget', source_input.url)
        source_sha = Digest::SHA256.hexdigest(open("R-#{source_input.version}.tar.gz").read)
        Runner.run('tar', 'xf', "R-#{source_input.version}.tar.gz")

        Dir.chdir("R-#{source_input.version}") do
          Runner.run('./configure', '--with-readline=no', '--with-x=no', '--enable-R-shlib')
          Runner.run('make')
          Runner.run('make install')

          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "install.packages('devtools', repos='https://cran.r-project.org')")

          rserve_version = rserve_input.split(".")[0..1].join(".") + "-" + rserve_input.split(".")[2..-1].join(".")

          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); install_version('Rserve', '#{rserve_version}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); install_version('forecast', '#{forecast_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); install_version('shiny', '#{shiny_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); install_version('plumber', '#{plumber_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")

          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', 'remove.packages("devtools")')

          Dir.chdir('/usr/local/lib/R') do
            case stack
            when 'cflinuxfs2'
              Runner.run('cp', '-L', '/usr/bin/gfortran-4.8', './bin/gfortran')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/f951', './bin/f951')
              Runner.run('ln', '-s', './gfortran', './bin/f95')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libcaf_single.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortran.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortran.so', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortranbegin.a', './lib')
            when 'cflinuxfs3'
              Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-7', './bin/gfortran')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/f951', './bin/f951')
              Runner.run('ln', '-s', './gfortran', './bin/f95')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libcaf_single.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libgfortran.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libgfortran.so', './lib')
            end
            Runner.run('tar', 'zcvf', "#{artifacts}/r-v#{source_input.version}.tgz", '.')
          end
        end
      end
    end
    source_sha
  end

  def replace_openssl()
    filebase = 'OpenSSL_1_1_0g'
    filename = "#{filebase}.tar.gz"
    openssltar = "https://github.com/openssl/openssl/archive/#{filename}"

    Dir.mktmpdir do |dir|
      Runner.run('wget', openssltar)
      Runner.run('tar', 'xf', filename)
      Dir.chdir("openssl-#{filebase}") do
        Runner.run("./config",
                   "--prefix=/usr",
                   "--libdir=/lib/x86_64-linux-gnu",
                   "--openssldir=/include/x86_64-linux-gnu/openssl")
        Runner.run('make')
        Runner.run('make', 'install_sw')
      end
    end
  end

  def build_python(source_input, stack)

    artifacts = "#{Dir.pwd}/artifacts"
    destdir = Dir.mktmpdir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('wget', source_input.url)
        # TODO validate pgp
        tar_name = source_input.name.capitalize
        Runner.run('tar', 'xf', "#{tar_name}-#{source_input.version}.tgz")

        # Python specific configuration here
        Dir.chdir("#{tar_name}-#{source_input.version}") do

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

          # replace openssl if needed
          major, minor, _ = source_input.version.split('.')
          if major == '3' && minor == '4' && stack == 'cflinuxfs3'
            Runner.run('apt', 'update')
            Runner.run('apt-get', 'install', '-y', 'libssl1.0-dev')
          elsif stack == 'cflinuxfs3' && major != '2'
            DependencyBuild.replace_openssl
          end

          Runner.run("make")
          Runner.run("make install")
          # create python symlink
          unless File.exist?("#{destdir}/bin/python")
            File.symlink('./python3', "#{destdir}/bin/python")
          end
          raise 'Could not run make install' unless $?.success?
          Dir.chdir(destdir) do
            Runner.run('tar', 'zcvf', "#{artifacts}/python-#{source_input.version}.tgz", '.', '--hard-dereference')
          end
        end
      end
    end
  end

  def build_nginx(source_input, stack, static = false)
    artifacts = "#{Dir.pwd}/artifacts"
    source_pgp = 'not yet implemented'
    destdir = Dir.mktmpdir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('wget', source_input.url)
        # TODO validate pgp
        Runner.run('tar', 'xf', "#{source_input.type}-#{source_input.version}.tar.gz")
        base_nginx_options = [
            '--prefix=/',
            '--error-log-path=stderr',
            '--with-http_ssl_module',
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
        ]

        nginx_static_options = [
            '--with-cc-opt=-fPIE -pie',
            '--with-ld-opt=-fPIE -pie -z now',
        ]

        nginx_options = [
            '--with-cc-opt=-fPIC -pie',
            '--with-ld-opt=-fPIC -pie -z now',
            '--with-compat',
            '--with-stream=dynamic',
            '--with-http_sub_module',
        ]

        DependencyBuild.replace_openssl if stack == 'cflinuxfs3'

        Dir.chdir("#{source_input.type}-#{source_input.version}") do
          options = ['./configure'] + base_nginx_options + (static ? nginx_static_options : nginx_options)
          Runner.run(*options)
          Runner.run('make')
          system({ 'DEBIAN_FRONTEND' => 'noninteractive', 'DESTDIR' => "#{destdir}/nginx" }, 'make install')
          raise 'Could not run make install' unless $?.success?

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

  def build_dotnet_sdk(source_input)
    prune_dotnet_files(source_input, ["./shared/*"])
  end

  def build_dotnet_runtime(source_input)
    prune_dotnet_files(source_input, ["./dotnet"])
  end

  def build_dotnet_aspnetcore(source_input)
    prune_dotnet_files(source_input, ["./dotnet", "./shared/Microsoft.NETCore.App/*"])
  end

  def prune_dotnet_files(source_input, files_to_exclude)
    source_file = File.expand_path(Dir.glob('source/*.tar.gz').first)
    adjusted_file = "/tmp/#{source_input.name}.#{source_input.version}.linux-amd64.tar.xz"
    exclude_list = files_to_exclude.map{ |file| "--exclude=#{file}"}.join(" ")
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        `tar -xf #{source_file} #{exclude_list}`
        # Use xz to compress smaller than gzip
        `tar -Jcf #{adjusted_file} ./*`
      end
    end
    adjusted_file
  end

  def build_openresty(source_input)
    artifacts = "#{Dir.pwd}/artifacts"
    destdir = Dir.mktmpdir

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('wget', source_input.url)
        # TODO validate pgp
        Runner.run('tar', 'xf', "#{source_input.name}-#{source_input.version}.tar.gz")
        Dir.chdir("#{source_input.name}-#{source_input.version}") do
          Runner.run(
              './configure',
              "--prefix=#{destdir}/openresty",
              '-j2',
              '--error-log-path=stderr',
              '--with-http_ssl_module',
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
              '--with-stream=dynamic',
          )
          Runner.run('make', '-j2')
          system({ 'DEBIAN_FRONTEND' => 'noninteractive' }, 'make install')
          raise 'Could not run make install' unless $?.success?

          Dir.chdir("#{destdir}/openresty") do
            Runner.run('rm', '-Rf', './nginx/html', './nginx/conf')
            Runner.run('mkdir', './nginx/conf')
            Runner.run('rm', './bin/openresty')
            Runner.run('tar', 'zcvf', "#{artifacts}/openresty-#{source_input.version}.tgz", '.')
          end
        end
      end
    end
  end
end

module Sha
  def get_sha(url)
    Digest::SHA256.hexdigest(open(url).read)
  end

  def check_sha(source_input)
    res = open(source_input.url).read
    sha = get_sha(source_input.url)
    if source_input.md5? && Digest::MD5.hexdigest(res) != source_input.md5
      raise 'MD5 digest does not match version digest'
    elsif source_input.sha256? && sha != source_input.sha256
      raise 'SHA256 digest does not match version digest'
    end
    [res, sha]
  end
end


class Builder

  def execute(binary_builder, stack, source_input, build_input, build_output, artifact_output, skip_commit = false)
    cnb_list = [
      'org.cloudfoundry.node-engine',
      'org.cloudfoundry.npm',
      'org.cloudfoundry.yarn',
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
      'org.cloudfoundry.httpd',
      'org.cloudfoundry.nginx',
      'org.cloudfoundry.php-web',
      'org.cloudfoundry.dotnet-core-build',
      'org.cloudfoundry.go-compiler',
      'org.cloudfoundry.go-mod',
      'org.cloudfoundry.dep',
    ]

    unless skip_commit
      build_input.copy_to_build_output
    end

    out_data = {
        tracker_story_id: build_input.tracker_story_id,
        version: source_input.version,
        source: { url: source_input.url }
    }
    out_data[:source][:md5] = source_input.md5
    out_data[:source][:sha256] = source_input.sha256

    unless out_data[:source][:sha256]
      out_data[:source][:sha256] = Sha::get_sha(source_input.url)
    end

    case source_input.name
    when 'bundler'
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/#{source_input.name}-#{source_input.version}.tgz",
              "#{source_input.name}-#{source_input.version}-#{stack}",
              'tgz'
          )
      )

    when 'hwc'
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/hwc-#{source_input.version}-windows-amd64.zip",
              "hwc-#{source_input.version}-windows-amd64",
              'zip'
          )
      )

    when 'dep', 'glide', 'godep'
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/#{source_input.name}-v#{source_input.version}-linux-x64.tgz",
              "#{source_input.name}-v#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'go'
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/go#{source_input.version}.linux-amd64.tar.gz",
              "go#{source_input.version}.linux-amd64-#{stack}",
              'tar.gz'
          )
      )

    when 'node', 'httpd'
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/#{source_input.name}-#{source_input.version}-linux-x64.tgz",
              "#{source_input.name}-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'nginx-static'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_nginx(source_input, stack, true)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "artifacts/nginx-#{source_input.version}.tgz",
              "nginx-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )
      out_data[:source_pgp] = source_pgp

    when 'CAAPM', 'appdynamics'
      results = Sha.check_sha(source_input)
      out_data[:sha256] = results[1]
      out_data[:url] = source_input.url

    when 'miniconda2', 'miniconda3'
      out_data[:url] = "https://github.com/conda/conda/archive/#{source_input.version}.tar.gz"
      results = Sha.check_sha(out_data[:url])
      out_data[:sha256] = results[1]

    when -> (elem) { cnb_list.include?(elem) }
      results = Sha.check_sha(source_input)
      File.write('artifacts/temp_file', results[0])

      cnbName = source_input.repo.split("/").last
      uri = "https://github.com/#{source_input.repo}/releases/download/v#{source_input.version}/#{cnbName}-#{source_input.version}.tgz"
      download = open(uri)
      IO.copy_stream(download, "artifacts/#{source_input.name}.tgz")

      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "artifacts/#{source_input.name}.tgz",
              "#{source_input.name}-#{source_input.version}-#{stack}",
              "tgz"
          )
      )

    when 'setuptools', 'rubygems', 'yarn', 'pip', 'bower', 'lifecycle' # TODO : fix me to use artifact_output
      results = Sha.check_sha(source_input)
      ext = File.basename(source_input.url)[/\.((zip|tar\.gz|tar\.xz|tgz))$/, 1]
      File.write('artifacts/temp_file', results[0])

      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              'artifacts/temp_file',
              "#{source_input.name}-#{source_input.version}-#{stack}",
              ext
          )
      )

    when 'composer'
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              'source/composer.phar',
              "#{source_input.name}-#{source_input.version}",
              'phar'
          )
      )

    when 'ruby'
      major, minor, _ = source_input.version.split('.')
      if major == '2' && stack == 'cflinuxfs3' && (minor == '3' || minor == '2')
        Runner.run('apt', 'update')
        Runner.run('apt-get', 'install', '-y', 'libssl1.0-dev')
      end
      binary_builder.build(source_input)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/ruby-#{source_input.version}-linux-x64.tgz",
              "#{source_input.name}-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'jruby'
      if /9.1.*/ =~ source_input.version
        # jruby 9.1.X.X will implement ruby 2.3.X
        ruby_version = '2.3'
      elsif /9.2.*/ =~ source_input.version
        # jruby 9.2.X.X will implement ruby 2.5.X
        ruby_version = '2.5'
      else
        raise "Unsupported jruby version line #{source_input.version}"
      end

      # Create a copy of the source_input to prevent mutating version for later use
      full_version = "#{source_input.version}_ruby-#{ruby_version}"
      binary_builder.build(
          SourceInput.new(
              source_input.name,
              source_input.url,
              full_version,
              source_input.md5,
              source_input.sha256,
              source_input.git_commit_sha
          )
      )

      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/#{source_input.name}-#{full_version}-linux-x64.tgz",
              "#{source_input.name}-#{full_version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'php'
      full_name = source_input.name
      if source_input.version.start_with?('7')
        full_name = 'php7'
      elsif !source_input.version.start_with?('7')
        raise "Unexpected PHP version #{source_input.version}. Expected 7.X"
      end

      base_extension_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php7-base-extensions.yml")
      php_extensions = BaseExtensions.new(base_extension_file)

      # figure out extensions file to use
      patch_file = nil
      if source_input.version.start_with?('7.1.')
        patch_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php71-extensions-patch.yml")
      elsif source_input.version.start_with?('7.2.')
        patch_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php72-extensions-patch.yml")
      elsif source_input.version.start_with?('7.3.')
        patch_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php73-extensions-patch.yml")
      end

      php_extensions.patch!(patch_file) if patch_file
      output_yml = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php-final-extensions.yml")
      php_extensions.write_yml(output_yml)

      binary_builder.build(source_input, "--php-extensions-file=#{output_yml}")
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "#{binary_builder.base_dir}/#{full_name}-#{source_input.version}-linux-x64.tgz",
              "#{full_name}-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'python'
      DependencyBuild.build_python(source_input, stack)
      out_data.merge!(
          artifact_output.move_dependency(
              'python',
              "artifacts/python-#{source_input.version}.tgz",
              "python-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )

    when 'pipenv'
      old_file_path = DependencyBuild.build_pipenv source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}-v#{source_input.version}-#{stack}",
              'tgz'
          )
      )

    when 'libunwind'
      old_file_path = DependencyBuild.build_libunwind source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}-#{source_input.version}-#{stack}",
              'tar.gz'
          )
      )

    when 'libgdiplus'
      old_file_path = DependencyBuild.build_libgdiplus source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}-#{source_input.version}-#{stack}",
              'tar.gz'
          )
      )

    when 'r'
      forecast_input = SourceInput.from_file("#{Dir.pwd}/source-forecast-latest/data.json")
      plumber_input = SourceInput.from_file("#{Dir.pwd}/source-plumber-latest/data.json")
      rserve_input = SourceInput.from_file("#{Dir.pwd}/source-rserve-latest/data.json")
      shiny_input = SourceInput.from_file("#{Dir.pwd}/source-shiny-latest/data.json")

      source_sha = DependencyBuild.build_r(source_input, forecast_input.version, plumber_input.version, rserve_input.version, shiny_input.version)

      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "artifacts/#{source_input.name}-v#{source_input.version}.tgz",
              "#{source_input.name}-v#{source_input.version}-#{stack}",
              'tgz'
          )
      )
      out_data[:git_commit_sha] = source_sha

      out_data[:sub_dependencies] = {}
      [forecast_input, plumber_input, rserve_input, shiny_input].each do |sub_dep|
        out_data[:sub_dependencies][sub_dep.name.to_sym] = { source: { url: sub_dep.url, sha256: sub_dep.sha_from_url() }, version: sub_dep.version }
      end

    when 'nginx'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_nginx(source_input, stack, false)
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "artifacts/#{source_input.name}-#{source_input.version}.tgz",
              "#{source_input.name}-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )
      out_data[:source_pgp] = source_pgp

    when 'dotnet-sdk'
      old_file_path = DependencyBuild.build_dotnet_sdk source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}.#{source_input.version}.linux-amd64-#{stack}",
              'tar.xz'
          )
      )

    when 'dotnet-runtime'
      old_file_path = DependencyBuild.build_dotnet_runtime source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}.#{source_input.version}.linux-amd64-#{stack}",
              'tar.xz'
          )
      )

    when 'dotnet-aspnetcore'
      old_file_path = DependencyBuild.build_dotnet_aspnetcore source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              old_file_path,
              "#{source_input.name}.#{source_input.version}.linux-amd64-#{stack}",
              'tar.xz'
          )
      )

    when 'openresty'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_openresty source_input
      out_data.merge!(
          artifact_output.move_dependency(
              source_input.name,
              "artifacts/#{source_input.name}-#{source_input.version}.tgz",
              "#{source_input.name}-#{source_input.version}-linux-x64-#{stack}",
              'tgz'
          )
      )
      out_data[:source_pgp] = source_pgp
    else
      raise("Dependency: #{source_input.name} is not currently supported")
    end

    unless skip_commit
      build_output.add_output("#{source_input.version}-#{stack}.json", out_data)
      build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack} [##{build_input.tracker_story_id}]")
    end

    out_data
  end
end

