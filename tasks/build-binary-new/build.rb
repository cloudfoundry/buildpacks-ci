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
  system(*args)
  raise "Could not run #{args}" unless $?.success?
end

case name
when 'pipenv'
  run('apt', 'update')
  run('apt-get', 'install', '-y', 'python-pip', 'python-dev', 'build-essential')
  run('pip', 'install', '--upgrade', 'pip')
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
when 'setuptools'
  res = open(url).read
  if Digest::MD5.hexdigest(res) != data.dig('version', 'md5_digest')
    raise "MD5 digest does not match version digest"
  end
  sha = Digest::SHA256.hexdigest(res)

  filename = File.basename(url).gsub(/(\.(zip|tar\.gz|tar\.xz|tgz))$/, "-#{sha[0..7]}\\1")
  File.write("artifacts/#{filename}", res)

  out_data.merge!({
    sha256: sha,
    url: "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
  })
when 'rubygems'
  res = open(url).read
  sha = Digest::SHA256.hexdigest(res)

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
