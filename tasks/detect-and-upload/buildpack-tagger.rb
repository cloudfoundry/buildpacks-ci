require 'fileutils'
require 'octokit'

class BuildpackTagger
  attr_reader :buildpack_dir, :buildpack_name, :git_repo_org

  def initialize(buildpack_dir, buildpack_name, git_repo_org)
    @buildpack_dir = buildpack_dir
    @buildpack_name = buildpack_name
    @git_repo_org = git_repo_org
  end

  def run!
    Dir.chdir(buildpack_dir) do
      tag_to_add = "v#{File.read('VERSION')}".strip
      puts "Tag to add: #{tag_to_add}"

      git_repo = "#{git_repo_org}/#{buildpack_name}"

      if ENV['GITHUB_TOKEN']
        client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
        existing_tags = client.tags(git_repo).map(&:name)
      else
        existing_tags = Octokit.tags(git_repo).map(&:name)
      end
      puts "Existing tags: #{existing_tags}"

      Dir.mkdir('../buildpack-artifacts/uncached')
      Dir.mkdir('../buildpack-artifacts/cached')

      if existing_tags.include? tag_to_add
        puts "Tag #{tag_to_add} already exists"
        uncached_buildpack = Dir['../pivotal-buildpack/*.zip'].first
        cached_buildpack = Dir['../pivotal-buildpack-cached/*.zip'].first

        if uncached_buildpack && cached_buildpack
          puts "Using existing artifacts - no rebuild needed"
          output_uncached = File.join('..', 'buildpack-artifacts', 'uncached', File.basename(uncached_buildpack))
          output_cached = File.join('..', 'buildpack-artifacts', 'cached', File.basename(cached_buildpack))

          FileUtils.mv(uncached_buildpack, output_uncached)
          FileUtils.mv(cached_buildpack, output_cached)
        else
          puts "Tag exists but no artifacts found - building from scratch"
          build_artifacts
        end
      else
        puts "New version detected - building artifacts"
        build_artifacts
      end
    end
  end

  private

  def build_artifacts
    stack = ENV.fetch('CF_STACK')
    stack_flag = stack == 'any' ? '--any-stack' : "--stack=#{stack}"

    if File.exist?('compile-extensions')
      system(<<~EOF)
        export BUNDLE_GEMFILE=cf.Gemfile
        if [ ! -z "$RUBYGEM_MIRROR" ]; then
          bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
        fi
        # Write a new Gemfile and Gemfile.lock to the buildpack directory
        # so that the buildpack-packager can use the correct versions of
        # the buildpack dependencies

        rm -rf cf.Gemfile
        rm -rf cf.Gemfile.lock

        wget https://github.com/cloudfoundry/php-buildpack/raw/v4.5.3/cf.Gemfile
        wget https://github.com/cloudfoundry/php-buildpack/raw/v4.5.3/cf.Gemfile.lock
        bundle install --deployment
        bundle cache
        bundle exec buildpack-packager --uncached #{stack_flag}
        bundle exec buildpack-packager --cached #{stack_flag}
      EOF
    elsif File.exist?('./scripts/.util/tools.sh')
      system('bash', '-c', <<~EOF)
        . ./scripts/.util/tools.sh
        util::tools::buildpack-packager::install --directory "${PWD}/.bin"
        ./.bin/buildpack-packager build --cached=false #{stack_flag}
        ./.bin/buildpack-packager build --cached=true #{stack_flag}
      EOF
    else
      system(<<~EOF)
        ./scripts/install_tools.sh
        ./.bin/buildpack-packager build --cached=false #{stack_flag}
        ./.bin/buildpack-packager build --cached=true #{stack_flag}
      EOF
    end

    timestamp = `date +%s`.strip

    Dir['*.zip'].map do |filename|
      filename.match(/(.*)_buildpack(-cached)?.*-v(.*).zip/) do |match|
        language = match[1]
        cached = match[2]
        version = match[3]
        stack_string = stack == 'any' ? '' : "-#{stack}"
        dir = cached ? 'cached' : 'uncached'

        output_file = "../buildpack-artifacts/#{dir}/#{language}_buildpack#{cached}#{stack_string}-v#{version}+#{timestamp}.zip"

        FileUtils.mv(filename, output_file)
      end
    end

    Dir.chdir('../buildpack-artifacts') do
      Dir['*/*.zip'].each do |buildpack|
        md5sum = `md5sum #{buildpack}`
        sha256sum = `sha256sum #{buildpack}`
        puts "md5: #{md5sum}"
        puts "sha256: #{sha256sum}"
      end
    end
  end
end
