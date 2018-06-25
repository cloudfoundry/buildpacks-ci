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
  filename = File.basename(old_file).gsub(/(\.tar.gz)$/, "-#{sha[0..7]}\\1")
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'dotnet'
  GitClient.clone_repo('https://github.com/dotnet/cli.git', 'cli')

  major, minor, patch = version.split('.')
  Dir.chdir('cli') do
    if version == '2.1.300' # See: https://github.com/dotnet/cli/issues/9388
      GitClient.checkout_branch('aeae506fa8d3571d8b5f75f81389003e0fb0273e')
    else
      GitClient.checkout_branch("v#{version}")
    end
    run('apt-get', 'update')
    run('apt-get', '-y', 'upgrade')
    run('apt-get', '-y', 'install', 'clang', 'devscripts', 'debhelper', 'libunwind8', 'liburcu1', 'libpython2.7', 'liblttng-ust0', 'libllvm3.6', 'liblldb-3.6')

    ENV['DropSuffix'] = 'true'
    ENV['TERM'] = 'linux'
    if major == '2' && minor == '1' && patch.to_i >= 4 && patch.to_i <= 200
      runbuildsh = File.open('run-build.sh', 'r') {|f| f.read}
      runbuildsh.gsub!('WriteDynamicPropsToStaticPropsFiles "${args[@]}"', 'WriteDynamicPropsToStaticPropsFiles')
      File.open('run-build.sh ', 'w') {|f| f.write runbuildsh}
    end
    run('./build.sh', '/t:Compile')
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
  filename = old_filename.gsub(/(\.(zip|tar\.gz|tar\.xz|tgz))$/, "-#{sha[0..7]}\\1")
  FileUtils.mv("/tmp/#{old_filename}", "artifacts/#{filename}")

  out_data.merge!({
    version: version,
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}",
    git_commit_sha: data.dig('version', 'git_commit_sha')
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
  filename = "pipenv-v#{version}-#{sha[0..7]}.tgz"
  FileUtils.mv("/tmp/pipenv-v#{version}.tgz", "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'CAAPM', 'appdynamics'
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
  filename = File.basename(old_file).gsub(/(\.tgz)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.zip)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.tar.gz)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.tar.gz)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.tar.gz)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.tar.gz)$/, "-#{sha[0..7]}\\1")
  FileUtils.mv(old_file, "artifacts/#{filename}")

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
  filename = File.basename(old_file).gsub(/(\.tgz)$/, "-#{sha[0..7]}\\1")
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
  filename = File.basename(old_file).gsub(/(\.tgz)$/, "-#{sha[0..7]}\\1")
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'httpd'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=httpd', "--version=#{version}", "--sha256=#{data.dig('version', 'sha256')}")
  end
  old_file = "binary-builder/httpd-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = File.basename(old_file).gsub(/(\.tgz)$/, "-#{sha[0..7]}\\1")
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
      run('apt', 'update')
      run('apt-get', 'install', '-y', 'gfortran', 'libbz2-dev', 'liblzma-dev', 'libpcre++-dev', 'libcurl4-openssl-dev', 'default-jre')
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
  filename = "r-v#{version}-#{sha[0..7]}.tgz"
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
  filename = "nginx-#{version}-linux-x64-#{sha[0..7]}.tgz"
  FileUtils.mv("artifacts/nginx-#{version}.tgz", "artifacts/#{filename}")

  out_data.merge!({
    source_pgp: source_pgp,
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/nginx/#{filename}"
  })
when 'nginx-static'
  source_pgp = 'unimplemented'
  Dir.chdir('binary-builder') do
    run('./bin/binary-builder', '--name=binary-builder', "--version=#{version}", '--gpg-signature=unimplemented', '--gpg-rsa-key-id=unimplemented')
  end
  old_file = "binary-builder/nginx-#{version}-linux-x64.tgz"
  sha = Digest::SHA256.hexdigest(open(old_file).read)
  filename = File.basename(old_file).gsub(/(\.tgz)$/, "-#{sha[0..7]}\\1")
  FileUtils.mv(old_file, "artifacts/#{filename}")

  out_data.merge!({
    source_pgp: source_pgp,
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

  File.write("binary-builds-new/#{name}/#{version}.json", out_data.to_json)

  GitClient.add_file("binary-builds-new/#{name}/#{version}.json")
  GitClient.safe_commit("Build #{name} - #{version} [##{tracker_story_id}]")
end
