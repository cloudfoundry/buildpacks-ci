require 'json'
require 'yaml'
require 'open-uri'
require 'pathname'
require 'digest'
require 'net/http'
require 'tmpdir'
require_relative 'merge-extensions'

module Runner
  class << self
    def run(*args)
      system({ 'DEBIAN_FRONTEND' => 'noninteractive' }, *args)
      raise "Could not run #{args}" unless $?.success?
    end
  end
end

module DependencyBuild
  class << self

    def setup_ruby
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'software-properties-common')
      Runner.run('apt-add-repository', '-y', 'ppa:brightbox/ruby-ng')
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'ruby2.7', 'ruby2.7-dev')
    end

    def setup_python
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'curl', 'python3.8', 'python3.8-distutils', 'python3.8-dev')
      Runner.run('curl', '-L', 'https://bootstrap.pypa.io/get-pip.py', '-o', 'get-pip.py')
      Runner.run('python3.8', 'get-pip.py')
      Runner.run('/usr/local/bin/pip3', 'install', '--upgrade', 'pip', 'setuptools')
      Runner.run('rm', '-f', 'get-pip.py')
    end

    # Sets up gcc8 - ubuntu:bionic comes with gcc7
    def setup_gcc
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'software-properties-common')
      Runner.run('add-apt-repository', '-y', 'ppa:ubuntu-toolchain-r/test')
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'gcc-8', 'g++-8')
      Runner.run('update-alternatives', '--install', '/usr/bin/gcc', 'gcc', '/usr/bin/gcc-8', '60', '--slave', '/usr/bin/g++', 'g++', '/usr/bin/g++-8')
    end

    # Sets up gcc9 - ubuntu:bionic comes with gcc7
    def setup_gcc9
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'software-properties-common')
      Runner.run('add-apt-repository', '-y', 'ppa:ubuntu-toolchain-r/test')
      Runner.run('apt', 'update')
      Runner.run('apt', 'install', '-y', 'gcc-9', 'g++-9')
      Runner.run('update-alternatives', '--install', '/usr/bin/gcc', 'gcc', '/usr/bin/gcc-9', '60', '--slave', '/usr/bin/g++', 'g++', '/usr/bin/g++-9')
    end

    def bundle_pip_dependencies(source_input)
      # final resting place for pip source and dependencies
      file_path = "/tmp/pip-#{source_input.version}.tgz"
      ENV['LC_CTYPE'] = 'en_US.UTF-8'

      # For the latest version of pip, it requires python version >= 3.7 (ref: https://github.com/pypa/pip/pull/10641),
      # so we need to install python >= 3.7 first.
      setup_python

      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', "pip==#{source_input.version}")
          if source_input.md5?
            if Digest::MD5.hexdigest(open("pip-#{source_input.version}.tar.gz").read) != source_input.md5
              raise 'MD5 digest does not match version digest'
            end
          elsif source_input.sha256?
            if Digest::SHA256.hexdigest(open("pip-#{source_input.version}.tar.gz").read) != source_input.sha256
              raise 'SHA256 digest does not match version digest'
            end
          else
            raise 'No digest specified for source'
          end
          Archive.strip_top_level_directory_from_tar("pip-#{source_input.version}.tar.gz")
          Runner.run('tar', 'zxf', "pip-#{source_input.version}.tar.gz")
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'setuptools')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'wheel')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'flit_core')
          Runner.run('tar', 'zcvf', file_path, '.')
        end
      end
      file_path
    end

    def build_pipenv(source_input)
      old_file_path = "/tmp/pipenv-v#{source_input.version}.tgz"
      ENV['LC_CTYPE'] = 'en_US.UTF-8'

      setup_python

      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          Runner.run('/usr/local/bin/pip3', 'download', '--no-cache-dir', '--no-binary', ':all:', "pipenv==#{source_input.version}")
          if source_input.md5?
            if Digest::MD5.hexdigest(open("pipenv-#{source_input.version}.tar.gz").read) != source_input.md5
              raise 'MD5 digest does not match version digest'
            end
          elsif source_input.sha256?
            if Digest::SHA256.hexdigest(open("pipenv-#{source_input.version}.tar.gz").read) != source_input.sha256
              raise 'SHA256 digest does not match version digest'
            end
          else
            raise 'No digest specified for source'
          end
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'pytest-runner')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'setuptools_scm')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'parver')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'wheel')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'invoke')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'flit_core')
          Runner.run('/usr/local/bin/pip3', 'download', '--no-binary', ':all:', 'hatch-vcs')
          Runner.run('tar', 'zcvf', old_file_path, '.')
        end
      end
      old_file_path
    end

    def build_poetry(source_input)
      old_file_path = "/tmp/poetry-v#{source_input.version}.tgz"
      ENV['LC_CTYPE'] = 'en_US.UTF-8'

      setup_python

      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          Runner.run('pip3', 'download', '--no-binary', ':all:', "poetry==#{source_input.version}")
          if source_input.md5?
            if Digest::MD5.hexdigest(open("poetry-#{source_input.version}.tar.gz").read) != source_input.md5
              raise 'MD5 digest does not match version digest'
            end
          elsif source_input.sha256?
            if Digest::SHA256.hexdigest(open("poetry-#{source_input.version}.tar.gz").read) != source_input.sha256
              raise 'SHA256 digest does not match version digest'
            end
          else
            raise 'No digest specified for source'
          end
          Runner.run('tar', 'zcvf', old_file_path, '.')
        end
      end
      old_file_path
    end

    def build_libunwind(source_input)
      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)

      url = "#{source_input.url}"
      file_path = url.slice((url.rindex('/') + 1)..(url.length))
      dir = file_path.delete_suffix(".tar.gz")

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
      File.join(built_path, old_filename)
    end

    def build_libgdiplus(source_input)
      Runner.run('apt', 'update')
      Runner.run('apt-get', 'install', '-y', 'automake', 'libtool')

      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)

      Runner.run('git', 'clone', '--single-branch', '--branch', "#{source_input.version}", "https://github.com/#{source_input.repo}",
                 "#{source_input.name}-#{source_input.version}")
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
          # Building R needs C++17 support which needs GCC9
          DependencyBuild.setup_gcc9

          Runner.run('mkdir', '-p', '/usr/share/man/man1')

          Runner.run('apt', 'update')

          stack = ENV.fetch('STACK')
          fs_specific_packages = ['libgfortran-7-dev']
          Runner.run('apt-get', 'install', '-y', 'gfortran', 'libbz2-dev', 'liblzma-dev', 'libpcre++-dev', 'libpcre2-dev', 'libcurl4-openssl-dev', 'libsodium-dev', 'libharfbuzz-dev', 'libfribidi-dev', 'default-jre', *fs_specific_packages)

          Runner.run('wget', source_input.url)
          source_sha = Digest::SHA256.hexdigest(open("R-#{source_input.version}.tar.gz").read)
          Runner.run('tar', 'xf', "R-#{source_input.version}.tar.gz")

          Dir.chdir("R-#{source_input.version}") do
            Runner.run('./configure', '--with-readline=no', '--with-x=no', '--enable-R-shlib')
            Runner.run('make')
            Runner.run('make install')

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "install.packages('devtools', repos='https://cran.r-project.org')")

            rserve_version = rserve_input.split(".")[0..1].join(".") + "-" + rserve_input.split(".")[2..-1].join(".")

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); devtools::install_version('Rserve', '#{rserve_version}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); devtools::install_version('forecast', '#{forecast_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); devtools::install_version('shiny', '#{shiny_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")
            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', "require('devtools'); devtools::install_version('plumber', '#{plumber_input}', repos='https://cran.r-project.org', type='source', dependencies=TRUE)")

            Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', 'remove.packages("devtools")')

            Dir.chdir('/usr/local/lib/R') do
              case stack
              when 'cflinuxfs3'
                Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-7', './bin/gfortran')
                Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/f951', './bin/f951')
                Runner.run('ln', '-s', './gfortran', './bin/f95')
                Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libcaf_single.a', './lib')
                Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libgfortran.a', './lib')
                Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/libgfortran.so', './lib')
                Runner.run('cp', '-L', '/usr/lib/x86_64-linux-gnu/libpcre2-8.so.0', './lib')
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
      tar_path = "#{Dir.pwd}/source/Python-#{source_input.version}.tgz"
      destdir = Dir.mktmpdir
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          unless File.exist?(tar_path)
            Runner.run('wget', source_input.url)
            tar_path = "Python-#{source_input.version}.tgz"
            # TODO validate pgp
          end

          Runner.run('tar', 'xf', tar_path)

          # Python specific configuration here
          Dir.chdir("Python-#{source_input.version}") do

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
          Runner.run('tar', 'xf', "nginx-#{source_input.version}.tar.gz")
          base_nginx_options = [
            '--prefix=/',
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
            '--with-debug',
          ]

          nginx_static_options = [
            '--with-cc-opt=-fPIE -pie',
            '--with-ld-opt=-fPIE -pie -z now',
          ]

          nginx_options = [
            '--with-cc-opt=-fPIC -pie',
            '--with-ld-opt=-fPIC -pie -z now',
            '--with-compat',
            '--with-mail=dynamic',
            '--with-mail_ssl_module',
            '--with-stream=dynamic',
            '--with-http_sub_module',
          ]

          DependencyBuild.replace_openssl if stack == 'cflinuxfs3'

          Dir.chdir("nginx-#{source_input.version}") do
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
      prune_dotnet_files(source_input, ["./shared/*"], true)
    end

    def build_dotnet_runtime(source_input)
      prune_dotnet_files(source_input, ["./dotnet"])
    end

    def build_dotnet_aspnetcore(source_input)
      prune_dotnet_files(source_input, ["./dotnet", "./shared/Microsoft.NETCore.App"])
    end

    def prune_dotnet_files(source_input, files_to_exclude, write_runtime = false)
      source_file = File.expand_path(Dir.glob('source/*.tar.gz').first)
      adjusted_file = "/tmp/#{source_input.name}.#{source_input.version}.linux-amd64.tar.xz"
      exclude_list = files_to_exclude.map { |file| "--exclude=#{file}" }.join(" ")
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

    def write_runtime_version_file(source_file, sdk_dir)
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

    def build_icu(source_input)
      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)

      Dir.chdir('source') do
        filename = Dir.glob('icu4c-*-src.tgz').first
        Runner.run('tar', 'zxf', filename)
        Dir.chdir('icu/source') do
          Runner.run('./runConfigureICU', 'Linux', "--prefix=#{built_path}/usr/local")
          Runner.run('make')
          Runner.run('make install')
        end
      end
      old_filename = "#{source_input.name}-#{source_input.version}.tgz"
      Dir.chdir(built_path) do
        Runner.run('tar', 'czf', old_filename, './usr')
      end
      File.join(built_path, old_filename)
    end

    def build_curl(source_input)
      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)

      Dir.chdir('source') do
        Runner.run('tar', 'zxf', "curl-#{source_input.version}.tar.gz")
        Dir.chdir("curl-#{source_input.version}") do
          Runner.run('./configure', "--prefix=#{built_path}", "--with-openssl")
          Runner.run('make')
          Runner.run('make install')
        end
      end
      old_filename = "#{source_input.name}-#{source_input.version}.tgz"
      Runner.run('tar', '-C', built_path, '-czf', old_filename, '.')
      File.join(Dir.pwd, old_filename)
    end

    def build_tini(source_input)
      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)
      Dir.mkdir(File.join(built_path, 'bin'))

      Dir.chdir('source') do
        Runner.run('tar', 'zxf', "#{source_input.version}")
        Dir.chdir(Dir.glob('krallin-tini-*').first) do
          Runner.run('cmake .')
          Runner.run('make')
          Runner.run("mv tini #{built_path}/bin")
        end
      end
      old_filename = "#{source_input.name}-#{source_input.version}.tgz"
      Runner.run('tar', '-C', built_path, '-czf', old_filename, 'bin')
      File.join(Dir.pwd, old_filename)
    end

    def build_rust(source_input)
      built_path = File.join(Dir.pwd, 'built')
      Dir.mkdir(built_path)
      Dir.mkdir(File.join(built_path, 'bin'))

      Dir.chdir('source') do
        Runner.run('tar', 'zxf', "rustc-#{source_input.version}-src.tar.gz")
        Dir.chdir("rustc-#{source_input.version}-src") do
          File.open('config.toml', 'w') do |f|
            f << "[rust]\n"
            f << "channel = 'stable'\n"
            f << "[build]\n"
            f << "docs = false\n"
            f << "compiler-docs = false\n"
            f << "extended = true\n"
            f << "tools = ['cargo', 'rust-analyzer']\n"
            f << "[install]\n"
            f << "prefix = '#{built_path}'\n"
          end
          Runner.run('./x.py build --stage 2 && ./x.py install')
        end
      end
      old_filename = "#{source_input.name}-#{source_input.version}.tgz"
      Runner.run('tar', '-C', built_path, '-czf', old_filename, '.')
      File.join(Dir.pwd, old_filename)
    end
  end
end

module Sha
  class << self
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
          zipfile = File.join(destination, filename)
          File.delete(zipfile)
          Runner.run('zip', '-r', zipfile, '.')
        end
      end
    end
  end
end

class Builder
  def execute(binary_builder, stack, source_input, build_input, build_output, artifact_output, dep_metadata_output, php_extensions_dir = __dir__, skip_commit = false)

    unless skip_commit
      build_input.copy_to_build_output
    end

    out_data = {
      version: source_input.version,
      source: {
        url: source_input.url,
        md5: source_input.md5,
        sha256: source_input.sha256
      }
    }

    unless out_data[:source][:sha256]
      out_data[:source][:sha256] = Sha::get_sha(source_input.url)
    end

    filename_prefix = "#{source_input.name}_#{source_input.version}"

    DependencyBuild.setup_ruby

    case source_input.name
    when 'bundler'
      binary_builder.build(source_input)
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "#{binary_builder.base_dir}/#{source_input.name}-#{source_input.version}.tgz",
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'hwc'
      binary_builder.build(source_input)
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "#{binary_builder.base_dir}/hwc-#{source_input.version}-windows-x86-64.zip",
          "#{filename_prefix}_windows_x86-64_any-stack",
        )
      )

    when 'dep', 'glide', 'godep'
      binary_builder.build(source_input)
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "#{binary_builder.base_dir}/#{source_input.name}-v#{source_input.version}-linux-x64.tgz",
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'go'
      source_input.version = source_input.version.delete_prefix('go')
      binary_builder.build(source_input)

      filename = "#{binary_builder.base_dir}/go#{source_input.version}.linux-amd64.tar.gz"
      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'node', 'httpd'
      DependencyBuild.setup_gcc

      source_input.version = source_input.version.delete_prefix('v') if source_input.name == 'node'
      binary_builder.build(source_input)

      filename = "#{binary_builder.base_dir}/#{source_input.name}-#{source_input.version}-linux-x64.tgz"
      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'nginx-static'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_nginx(source_input, stack, true)

      filename = "artifacts/nginx-#{source_input.version}.tgz"
      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )
      out_data[:source_pgp] = source_pgp

    when 'appdynamics'
      filename = "source/appdynamics-php-agent-linux_x64-#{source_input.version}.tar.bz2"

      if File.exist?(filename)
        out_data.merge!(
          artifact_output.move_dependency(
            source_input.name,
            filename,
            "#{filename_prefix}_linux_x64_#{stack}"
          )
        )
      else
        results = Sha.check_sha(source_input)
        out_data[:sha256] = results[1]
        out_data[:url] = source_input.url
      end

    when 'CAAPM'
      filename = "source/CA-APM-PHPAgent-#{source_input.version}_linux.tar.gz"

      if File.exist?(filename)
        out_data.merge!(
          artifact_output.move_dependency(
            source_input.name,
            filename,
            "#{filename_prefix}_linux_x64_#{stack}"
          )
        )
      else
        results = Sha.check_sha(source_input)
        out_data[:sha256] = results[1]
        out_data[:url] = source_input.url
      end

    when -> (elem) { elem.start_with?('miniconda') }
      results = Sha.check_sha(source_input)
      out_data[:url] = source_input.url
      out_data[:sha256] = results[1]

    when 'setuptools'
      results = Sha.check_sha(source_input)
      filename = 'artifacts/temp_' + "#{source_input.url}".split('/').last
      File.write(filename, results[0])

      if "#{source_input.url}".end_with?(".tar.gz", ".tgz")
        Archive.strip_top_level_directory_from_tar(filename)
      else
        Archive.strip_top_level_directory_from_zip(filename, Dir.pwd)
      end

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'rubygems', 'yarn'
      source_input.version = source_input.version.delete_prefix('v') if source_input.name == 'yarn'
      results = Sha.check_sha(source_input)
      filename = 'artifacts/temp_file.tgz'
      File.write(filename, results[0])

      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'icu'
      old_file_path = DependencyBuild.build_icu source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'bower', 'lifecycle'
      results = Sha.check_sha(source_input)
      filename = 'artifacts/temp_file.tgz'
      File.write(filename, results[0])

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'composer'
      filename = "source/composer.phar"
      if File.exist?(filename)
        out_data.merge!(
          artifact_output.move_dependency(
            source_input.name,
            filename,
            "#{filename_prefix}_linux_noarch_any-stack",
          )
        )
      else
        results = Sha.check_sha(source_input)
        out_data[:sha256] = results[1]
        out_data[:url] = source_input.url
      end

    when 'ruby'
      major, minor, _ = source_input.version.split('.')
      if major == '2' && stack == 'cflinuxfs3' && (minor == '3' || minor == '2')
        Runner.run('apt', 'update')
        Runner.run('apt-get', 'install', '-y', 'libssl1.0-dev')
      end

      binary_builder.build(source_input)

      filename = "#{binary_builder.base_dir}/ruby-#{source_input.version}-linux-x64.tgz"
      Archive.strip_incorrect_words_yaml_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'jruby'
      if /9.2.*/ =~ source_input.version
        # jruby 9.2.X.X will implement ruby 2.5.X
        ruby_version = '2.5'
      elsif /9.3.*/ =~ source_input.version
        # jruby 9.3.X.X will implement ruby 2.6.X
        ruby_version = '2.6'
      elsif /9.4.*/ =~ source_input.version
        # jruby 9.4.X.X will implement ruby 3.1.X
        ruby_version = '3.1'
      else
        raise "Unsupported jruby version line #{source_input.version}"
      end

      # Create a copy of the source_input to prevent mutating version for later use
      full_version = "#{source_input.version}-ruby-#{ruby_version}"

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

      filename = "#{binary_builder.base_dir}/#{source_input.name}-#{full_version}-linux-x64.tgz"
      Archive.strip_incorrect_words_yaml_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{source_input.name}_#{full_version}_linux_x64_#{stack}",
        )
      )

    when 'php'
      base_extension_file = ''
      if source_input.version.start_with?('8')
        base_extension_file = File.join(php_extensions_dir, 'php8-base-extensions.yml')
      else
        raise "Unexpected PHP version #{source_input.version}. Expected 8.X"
      end

      php_extensions = BaseExtensions.new(base_extension_file)

      patch_file = nil
      if source_input.version.start_with?('8.1.')
        patch_file = File.join(php_extensions_dir, 'php81-extensions-patch.yml')
      elsif source_input.version.start_with?('8.2.')
        patch_file = File.join(php_extensions_dir, 'php82-extensions-patch.yml')
      elsif source_input.version.start_with?('8.3.')
        patch_file = File.join(php_extensions_dir, 'php83-extensions-patch.yml')
      end

      php_extensions.patch!(patch_file) if patch_file
      output_yml = File.join(php_extensions_dir, 'php-final-extensions.yml')
      php_extensions.write_yml(output_yml)

      binary_builder.build(source_input, "--php-extensions-file=#{output_yml}")

      filename = "#{binary_builder.base_dir}/php-#{source_input.version}-linux-x64.tgz"
      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "php_#{source_input.version}_linux_x64_#{stack}",
        )
      )

      out_data[:sub_dependencies] = {}
      extensions = [php_extensions.base_yml['native_modules'], php_extensions.base_yml['extensions']].flatten
      extensions.sort_by { |e| e['name'].downcase }.each do |extension|
        out_data[:sub_dependencies][extension['name'].to_sym] = { version: extension['version'] }
      end

    when 'python'
      DependencyBuild.build_python(source_input, stack)
      out_data.merge!(
        artifact_output.move_dependency(
          'python',
          "artifacts/python-#{source_input.version}.tgz",
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'pipenv'
      old_file_path = DependencyBuild.build_pipenv source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'poetry'
      old_file_path = DependencyBuild.build_poetry source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'pip'
      old_file_path = DependencyBuild.bundle_pip_dependencies source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'libunwind'
      old_file_path = DependencyBuild.build_libunwind source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'libgdiplus'
      old_file_path = DependencyBuild.build_libgdiplus source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
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
          "#{filename_prefix}_linux_noarch_#{stack}",
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

      filename = "artifacts/#{source_input.name}-#{source_input.version}.tgz"
      Archive.strip_top_level_directory_from_tar(filename)

      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          filename,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )
      out_data[:source_pgp] = source_pgp

    when 'dotnet-sdk'
      old_file_path = DependencyBuild.build_dotnet_sdk source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'dotnet-runtime'
      old_file_path = DependencyBuild.build_dotnet_runtime source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'dotnet-aspnetcore'
      old_file_path = DependencyBuild.build_dotnet_aspnetcore source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )

    when 'openresty'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_openresty source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "artifacts/#{source_input.name}-#{source_input.version}.tgz",
          "#{filename_prefix}_linux_x64_#{stack}",
        )
      )
      out_data[:source_pgp] = source_pgp
    when 'curl'
      old_file_path = DependencyBuild.build_curl source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )
    when 'tini'
      old_file_path = DependencyBuild.build_tini source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    when 'rust'
      Runner.run('apt', 'update')
      Runner.run('apt-get', 'install', '-y', 'ninja-build')

      # Rust requires CMake version 3.13.4 or later and the latest available on
      # apt-get is 3.10.2
      Runner.run('apt-get', 'remove', '-y', 'cmake')
      Runner.run('wget', 'https://github.com/Kitware/CMake/releases/download/v3.20.2/cmake-3.20.2-linux-x86_64.tar.gz')
      Runner.run('tar', '-xzf', 'cmake-3.20.2-linux-x86_64.tar.gz', '-C', '/usr/local', '--strip-components=1')

      old_file_path = DependencyBuild.build_rust source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          old_file_path,
          "#{filename_prefix}_linux_noarch_#{stack}",
        )
      )

    else
      raise("Dependency: #{source_input.name} is not currently supported")
    end

    unless skip_commit
      build_output.add_output("#{source_input.version}-#{stack}.json", out_data)
      build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack}")
    end

    dep_metadata_output.write_metadata(out_data[:url], out_data)

    out_data
  end
end
