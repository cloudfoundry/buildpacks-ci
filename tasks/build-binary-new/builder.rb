require 'json'
require 'open-uri'
require 'digest'
require 'net/http'
require 'tmpdir'
require_relative 'dotnet_framework_extractor'

module Runner
  def run(*args)
    system({'DEBIAN_FRONTEND' => 'noninteractive'}, *args)
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

  def build_r(source_input)
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

          Runner.run('/usr/local/lib/R/bin/R', '--vanilla', '-e', 'install.packages(c("Rserve","forecast","shiny", "plumber"), repos="https://cran.r-project.org", dependencies=TRUE)')

          Dir.chdir('/usr/local/lib/R') do
            case stack
            when 'cflinuxfs2'
              Runner.run('cp', '-L', '/usr/bin/gfortran-4.8', './bin/gfortran')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/f951', './bin/f951')
              Runner.run('ln', '-s', './bin/gfortran','./bin/f95')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libcaf_single.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortran.a', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortran.so', './lib')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/4.8/libgfortranbegin.a', './lib')
            when 'cflinuxfs3'
              Runner.run('cp', '-L', '/usr/bin/x86_64-linux-gnu-gfortran-7', './bin/gfortran')
              Runner.run('cp', '-L', '/usr/lib/gcc/x86_64-linux-gnu/7/f951',  './bin/f951')
              Runner.run('ln', '-s', './bin/gfortran','./bin/f95')
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

  def build_nginx(source_input)
    artifacts = "#{Dir.pwd}/artifacts"
    source_pgp = 'not yet implemented'
    destdir = Dir.mktmpdir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Runner.run('wget', source_input.url)
        # TODO validate pgp
        Runner.run('tar', 'xf', "#{source_input.name}-#{source_input.version}.tar.gz")
        Dir.chdir("#{source_input.name}-#{source_input.version}") do
          Runner.run(
            './configure',
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
            '--with-cc-opt=-fPIC -pie',
            '--with-ld-opt=-fPIC -pie -z now',
            '--with-compat',
            '--with-stream=dynamic',
          )
          Runner.run('make')
          system({'DEBIAN_FRONTEND' => 'noninteractive', 'DESTDIR' => "#{destdir}/nginx"}, 'make install')
          raise 'Could not run make install' unless $?.success?

          Dir.chdir(destdir) do
            Runner.run('rm', '-Rf', './nginx/html', './nginx/conf')
            Runner.run('mkdir', 'nginx/conf')
            Runner.run('tar', 'zcvf', "#{artifacts}/nginx-#{source_input.version}.tgz", '.')
          end
        end
      end
    end
  end

  def build_dotnet_sdk(source_input, build_input, build_output, artifact_output)
    GitClient.clone_repo('https://github.com/dotnet/cli.git', 'cli')

    stack = ENV.fetch('STACK')
    major, minor, patch = source_input.version.split('.')
    Dir.chdir('cli') do
      GitClient.checkout(source_input.git_commit_sha)

      # TODO: This is a temporary workaround to get 2.1.401 to build properly.
      # Remove this block after 2.1.402 is released and builds properly.
      # See: https://github.com/dotnet/cli/issues/9897#issuecomment-416361988
      if [major, minor, patch] == %w(2 1 401)
        GitClient.cherry_pick('257cf7a4784cc925742ef4e2706e752ab1f578b0')
      end

      Runner.run('apt-get', 'update')
      Runner.run('apt-get', '-y', 'upgrade')
      fs_specific_packages = stack == 'cflinuxfs2' ? ['liburcu1', 'libllvm3.6', 'liblldb-3.6'] : ['liburcu6', 'libllvm3.9', 'liblldb-3.9']
      Runner.run('apt-get', '-y', 'install', 'clang', 'devscripts', 'debhelper', 'libunwind8', 'libpython2.7', 'liblttng-ust0', *fs_specific_packages)

      ENV['DropSuffix'] = 'true'
      ENV['TERM'] = 'linux'

      # We must fix the build script for dotnet-sdk versions 2.1.4 to 2.1.2XX (see https://github.com/dotnet/cli/issues/8358)
      if major == '2' && minor == '1' && patch.to_i >= 4 && patch.to_i < 300
        runbuildsh = File.open('run-build.sh', 'r') {|f| f.read}
        runbuildsh.gsub!('WriteDynamicPropsToStaticPropsFiles "${args[@]}"', 'WriteDynamicPropsToStaticPropsFiles')
        File.open('run-build.sh ', 'w') {|f| f.write runbuildsh}
      end

      Runner.run('./build.sh', '/t:Compile')
    end

    # The path to the built files changes in dotnet-v2.1.300
    has_artifacts_dir = major.to_i <= 2 && minor.to_i <= 1 && patch.to_i < 300
    old_filepath = "/tmp/#{source_input.name}.#{source_input.version}.linux-amd64.tar.xz"
    dotnet_dir = has_artifacts_dir ? Dir['cli/artifacts/*-x64/stage2'][0] : 'cli/bin/2/linux-x64/dotnet'

    remove_frameworks = major.to_i >= 2 && minor.to_i >= 1
    framework_extractor = DotnetFrameworkExtractor.new(dotnet_dir, stack, source_input, build_input, artifact_output)
    framework_extractor.extract_runtime(remove_frameworks)

    # There are only separate ASP.net packages for dotnet core 2+
    if major.to_i >= 2
      framework_extractor.extract_aspnetcore(remove_frameworks)
    end

    Dir.chdir(dotnet_dir) do
      system('tar', 'Jcf', old_filepath, '.')
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
  def execute(binary_builder, stack, source_input, build_input, build_output, artifact_output)
    build_input.copy_to_build_output

    out_data = {
      tracker_story_id: build_input.tracker_story_id,
      version: source_input.version,
      source: {url: source_input.url}
    }
    out_data[:source][:md5] = source_input.md5
    out_data[:source][:sha256] = source_input.sha256

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
      source_input.sha256 = Sha.get_sha(source_input.url)
      binary_builder.build(source_input)
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "#{binary_builder.base_dir}/#{source_input.name}-#{source_input.version}-linux-x64.tgz",
          "nginx-#{source_input.version}-linux-x64-#{stack}", # want filename in manifest to read 'nginx-...', not 'nginx-static-...'
          'tgz'
        )
      )

    when 'CAAPM', 'appdynamics', 'miniconda2', 'miniconda3'
      results = Sha.check_sha(source_input)
      out_data[:sha256] = results[1]
      out_data[:url] = source_input.url

    when 'setuptools', 'rubygems', 'yarn', 'pip', 'bower' # TODO : fix me to use artifact_output
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
      elsif !source_input.version.start_with?('5')
        raise "Unexpected PHP version #{source_input.version}. Expected 5.X or 7.X"
      end

      # add the right extensions
      extension_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "#{full_name}-extensions.yml")
      if source_input.version.start_with?('7.2.')
        extension_file = File.join($buildpacks_ci_dir, 'tasks', 'build-binary-new', "php72-extensions.yml")
      end
      binary_builder.build(source_input, "--php-extensions-file=#{extension_file}")
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "#{binary_builder.base_dir}/#{full_name}-#{source_input.version}-linux-x64.tgz",
          "#{full_name}-#{source_input.version}-linux-x64-#{stack}",
          'tgz'
        )
      )

    when 'python'
      major, minor, _ = source_input.version.split('.')
      if major == '3' && minor == '4' && stack == 'cflinuxfs3'
        Runner.run('apt', 'update')
        Runner.run('apt-get', 'install', '-y', 'libssl1.0-dev')
      end
      binary_builder.build(source_input)
      out_data.merge!(
        artifact_output.move_dependency(
          'python',
          "#{binary_builder.base_dir}/python-#{source_input.version}-linux-x64.tgz",
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

    when 'r'
      source_sha = DependencyBuild.build_r source_input
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "artifacts/#{source_input.name}-v#{source_input.version}.tgz",
          "#{source_input.name}-v#{source_input.version}-#{stack}",
          'tgz'
        )
      )
      out_data[:git_commit_sha] = source_sha

    when 'nginx'
      source_pgp = 'not yet implemented'
      DependencyBuild.build_nginx source_input
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
      DependencyBuild.build_dotnet_sdk source_input, build_input, build_output, artifact_output
      out_data.merge!(
        artifact_output.move_dependency(
          source_input.name,
          "/tmp/#{source_input.name}.#{source_input.version}.linux-amd64.tar.xz",
          "#{source_input.name}.#{source_input.version}.linux-amd64-#{stack}",
          'tar.xz'
        )
      )
      out_data.merge!({
        version: source_input.version,
        git_commit_sha: source_input.git_commit_sha
      })

    else
      raise("Dependency: #{source_input.name} is not currently supported")
    end

    build_output.add_output("#{source_input.version}-#{stack}.json", out_data)
    build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack} [##{build_input.tracker_story_id}]")

    out_data
  end
end

