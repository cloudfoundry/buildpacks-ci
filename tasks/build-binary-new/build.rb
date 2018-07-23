#!/usr/bin/env ruby
require 'json'
require 'open-uri'
require 'digest'
require 'net/http'
require 'tmpdir'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

system('rsync -a builds/ builds-artifacts/') or raise('Could not copy builds to builds artifacts')

data = JSON.parse(open('source/data.json').read)
version = data.dig('version', 'ref')
stack = ENV.fetch('STACK')
url = data.dig('version', 'url')
name = data.dig('source', 'name')
build = JSON.parse(open("builds/binary-builds-new/#{name}/#{version}.json").read)
tracker_story_id = build.dig('tracker_story_id')
out_data = {
  tracker_story_id: tracker_story_id,
  version: version,
  source: { url: url }
}
out_data[:source][:md5] = data.dig('version', 'md5_digest') if data.dig('version', 'md5_digest')
out_data[:source][:sha256] = data.dig('version', 'sha256') if data.dig('version', 'sha256')

def run(*args)
  system({'DEBIAN_FRONTEND' => 'noninteractive'}, *args)
  raise "Could not run #{args}" unless $?.success?
end

case name
when 'bundler'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=bundler', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/bundler-#{version}.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "bundler-#{version}-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'dotnet'
  commit_sha = data.dig('version', 'git_commit_sha')

  GitClient.clone_repo('https://github.com/dotnet/cli.git', 'cli')

  major, minor, patch = version.split('.')
  Dir.chdir('cli') do
    GitClient.checkout_branch(commit_sha)
    run('apt-get', 'update')
    run('apt-get', '-y', 'upgrade')
    fs_specific_packages = stack == 'cflinuxfs2' ? ['liburcu1', 'libllvm3.6', 'liblldb-3.6'] : ['liburcu6', 'libllvm3.9', 'liblldb-3.9']
    run('apt-get', '-y', 'install', 'clang', 'devscripts', 'debhelper', 'libunwind8', 'libpython2.7', 'liblttng-ust0', *fs_specific_packages)

    ENV['DropSuffix'] = 'true'
    ENV['TERM'] = 'linux'

    # We must fix the build script for dotnet versions 2.1.4 to 2.1.2XX (see https://github.com/dotnet/cli/issues/8358)
    if major == '2' && minor == '1' && patch.to_i >= 4 && patch.to_i < 300
      runbuildsh = File.open('run-build.sh', 'r') {|f| f.read}
      runbuildsh.gsub!('WriteDynamicPropsToStaticPropsFiles "${args[@]}"', 'WriteDynamicPropsToStaticPropsFiles')
      File.open('run-build.sh ', 'w') {|f| f.write runbuildsh}

      run('./build.sh')
    else
      run('./build.sh', '/t:Compile')
    end
  end

  # The path to the built files changes in dotnet-v2.1.300
  has_artifacts_dir = major.to_i <= 2 && minor.to_i <= 1 && patch.to_i < 300
  old_filename = "#{name}.#{version}.linux-amd64.tar.xz"
  Dir.chdir(if has_artifacts_dir
              Dir['cli/artifacts/*-x64/stage2'][0]
            else
              'cli/bin/2/linux-x64/dotnet'
            end) do
    system('tar', 'Jcf', "/tmp/#{old_filename}", '.')
  end
  sha = Digest::SHA256.hexdigest(open("/tmp/#{old_filename}").read)
  filename = "#{name}.#{version}.linux-amd64-#{stack}-#{sha[0..7]}.tar.xz"
  FileUtils.mv("/tmp/#{old_filename}", "artifacts/#{filename}")

  out_data.merge!({
    version: version,
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}",
    git_commit_sha: commit_sha
  })
when 'pipenv'
  run('apt', 'update')
  run('apt-get', 'install', '-y', 'python-pip', 'python-dev', 'build-essential')
  run('pip', 'install', '--upgrade', 'pip')
  run('pip', 'install', '--upgrade', 'setuptools')
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', "pipenv==#{version}")
      if Digest::MD5.hexdigest(open("pipenv-#{version}.tar.gz").read) != data.dig('version', 'md5_digest')
        raise 'MD5 digest does not match version digest'
      end
      run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'pytest-runner')
      run('/usr/local/bin/pip', 'download', '--no-binary', ':all:', 'setuptools_scm')
      run('tar', 'zcvf', "/tmp/pipenv-v#{version}.tgz", '.')
    end
  end
  sha = Digest::SHA256.hexdigest(open("/tmp/pipenv-v#{version}.tgz").read)
  filename = "pipenv-v#{version}-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv("/tmp/pipenv-v#{version}.tgz", "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'CAAPM', 'appdynamics', 'miniconda2', 'miniconda3'
  res = open(url).read
  sha = Digest::SHA256.hexdigest(res)
  if data.dig('version', 'md5_digest') && Digest::MD5.hexdigest(res) != data.dig('version', 'md5_digest')
    raise "MD5 digest does not match version digest"
  elsif data.dig('version', 'sha256') && sha != data.dig('version', 'sha256')
    raise "SHA256 digest does not match version digest"
  end

  out_data.merge!({
    sha256: sha,
    url: url
  })
when 'composer'
  sha = data.dig('version', 'sha256')
  input_path = "source/composer.phar"
  filename = "composer-#{version}-#{sha[0..7]}.phar"
  output_path = "artifacts/#{filename}"
  FileUtils.mv(input_path, output_path)

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'setuptools', 'rubygems', 'yarn', 'pip', 'bower'
  res = open(url).read
  sha = Digest::SHA256.hexdigest(res)
  if data.dig('version', 'md5_digest') && Digest::MD5.hexdigest(res) != data.dig('version', 'md5_digest')
    raise "MD5 digest does not match version digest"
  elsif data.dig('version', 'sha256') && sha != data.dig('version', 'sha256')
    raise "SHA256 digest does not match version digest"
  end

  filename = File.basename(url).gsub(/(\.(zip|tar\.gz|tar\.xz|tgz))$/, "-#{sha[0..7]}\\1")
  File.write("artifacts/#{filename}", res)

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'ruby'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=ruby', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/ruby-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "ruby-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'hwc'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=hwc', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/hwc-#{version}-windows-amd64.zip"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "hwc-#{version}-windows-amd64-#{sha[0..7]}.zip"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'dep'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=dep', "--version=v#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/dep-v#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "dep-v#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'glide'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=glide', "--version=v#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/glide-v#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "glide-v#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'godep'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=godep', "--version=v#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/godep-v#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "godep-v#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'go'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=go', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/go#{version}.linux-amd64.tar.gz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "go#{version}.linux-amd64-#{stack}-#{sha[0..7]}.tar.gz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'jruby'
  if /9.1.*/ =~ version
    # jruby 9.1.X.X will implement ruby 2.3.X
    ruby_version = '2.3'
  elsif /9.2.*/ =~ version
    # jruby 9.2.X.X will implement ruby 2.5.X
    ruby_version = '2.5'
  else
    raise "Unsupported jruby version line #{version}"
  end
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=jruby', "--version=#{version}_ruby-#{ruby_version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/jruby-#{version}_ruby-#{ruby_version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "jruby-#{version}_ruby-#{ruby_version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'libunwind'
  built_path = File.join(Dir.pwd, 'built')
  Dir.mkdir(built_path)

  Dir.chdir('source') do
    # github-releases depwatcher has already downloaded .tar.gz
    run('tar', 'zxf', "libunwind-#{version}.tar.gz")
    Dir.chdir("libunwind-#{version}") do
      run('./configure', "--prefix=#{built_path}")
      run('make')
      run('make install')
    end
  end
  old_filename = "libunwind-#{version}.tgz"
  Dir.chdir(built_path) do
    run('tar', 'czf', old_filename, 'include', 'lib')
  end
  old_filename = File.join(built_path,old_filename)
  sha = Digest::SHA256.hexdigest(open(old_filename).read)
  filename = "libunwind-#{version}-#{stack}-#{sha[0..7]}.tar.gz"
  FileUtils.mv(old_filename, "artifacts/#{filename}")
  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'node'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=node', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/node-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "node-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'php'
  if version.start_with?("7")
    phpV = "7"
  elsif version.start_with?("5")
    phpV = ""  # binary-builder expects 'php' to mean php 5.X.
  else
    raise "Unexpected PHP version #{version}. Expected 5.X or 7.X"
  end

  # add the right extensions
  extension_file = File.join(buildpacks_ci_dir, 'tasks', 'build-binary-new', "php#{phpV}-extensions.yml")
  if version.start_with?('7.2.')
    extension_file = File.join(buildpacks_ci_dir, 'tasks', 'build-binary-new', "php72-extensions.yml")
  end

  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', "--name=php#{phpV}", "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}", "--php-extensions-file=#{extension_file}")
  end
  old_file = "binary-builder/php#{phpV}-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "php#{phpV}-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'python'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=python', "--version=#{version}", "--md5=#{data.dig('version', 'md5')}")
  end
  old_file = "binary-builder/python-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "python-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'httpd'
  Dir.chdir('binary-builder') do
    run('apt', 'update')
    run('apt-get', 'install', '-y', 'libssl-dev', 'libldap2-dev')
    run('./bin/binary-builder', '--name=httpd', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/httpd-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "httpd-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'r'
  artifacts = "#{Dir.pwd}/artifacts"
  source_sha = ''
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      run('mkdir', '-p', '/usr/share/man/man1')
      run('apt', 'update')
      run('apt-get', 'install', '-y', 'gfortran', 'libssl-dev', 'libbz2-dev', 'liblzma-dev', 'libpcre++-dev', 'libcurl4-openssl-dev', 'default-jre')
      run('wget', url)
      source_sha = Digest::SHA256.hexdigest(open("R-#{version}.tar.gz").read)
      run('tar', 'xf', "R-#{version}.tar.gz")
      Dir.chdir("R-#{version}") do
        run('./configure','--with-readline=no','--with-x=no','--enable-R-shlib')
        run('make')
        run('make install')

        run('/usr/local/lib/R/bin/R','--vanilla','-e','install.packages(c("Rserve","forecast"), repos="https://cran.r-project.org", dependencies=TRUE)')

        Dir.chdir('/usr/local/lib/R') do
          run('tar', 'zcvf', "#{artifacts}/r-v#{version}.tgz", '.')
        end
      end
    end
  end

  sha = Digest::SHA256.hexdigest(open("artifacts/r-v#{version}.tgz").read)
  filename = "r-v#{version}-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv("artifacts/r-v#{version}.tgz", "artifacts/#{filename}")

  out_data.merge!({
    source_sha256: source_sha,
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'nginx'
  artifacts = "#{Dir.pwd}/artifacts"
  source_pgp = 'not yet implemented'
  destdir = Dir.mktmpdir
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      run('apt', 'update')
      run('apt-get', 'install', '-y', 'libssl-dev')
      run('wget', data.dig('version', 'url'))
      # TODO validate pgp
      run('tar', 'xf', "nginx-#{version}.tar.gz")
      Dir.chdir("nginx-#{version}") do
        run(
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
          '--with-stream=dynamic',
        )
        run('make')
        system({'DEBIAN_FRONTEND' => 'noninteractive', 'DESTDIR'=>"#{destdir}/nginx"}, 'make install')
        raise "Could not run make install" unless $?.success?

        Dir.chdir(destdir) do
          run('rm', '-Rf', './nginx/html', './nginx/conf')
          run('mkdir', 'nginx/conf')
          run('tar', 'zcvf', "#{artifacts}/nginx-#{version}.tgz", '.')
        end
      end
    end
  end

  sha = Digest::SHA256.hexdigest(open("artifacts/nginx-#{version}.tgz").read)
  filename = "nginx-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv("artifacts/nginx-#{version}.tgz", "artifacts/#{filename}")

  out_data.merge!({
    source_pgp: source_pgp,
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/nginx/#{filename}"
  })
when 'nginx-static'
  old_sha = Digest::SHA256.hexdigest(open(data.dig('version', 'url')).read)
  Dir.chdir('binary-builder') do
    run('apt', 'update')
    run('apt-get', 'install', '-y', 'libssl-dev')
    run('./bin/binary-builder', '--name=nginx', "--version=#{version}", "--sha256=#{old_sha}")
  end
  old_file = "binary-builder/nginx-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = "nginx-#{version}-linux-x64-#{stack}-#{sha[0..7]}.tgz"
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
else
  raise("Dependency: #{name} is not currently supported")
end

p out_data

Dir.chdir('builds-artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write("binary-builds-new/#{name}/#{version}-#{stack}.json", out_data.to_json)

  GitClient.add_file("binary-builds-new/#{name}/#{version}-#{stack}.json")
  GitClient.safe_commit("Build #{name} - #{version} - #{stack} [##{tracker_story_id}]")
end
