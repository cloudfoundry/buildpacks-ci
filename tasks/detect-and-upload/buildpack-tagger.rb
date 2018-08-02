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

      existing_tags = Octokit.tags("#{git_repo_org}/#{buildpack_name}").map(&:name)
      puts "Existing tags: #{existing_tags}"

      if existing_tags.include? tag_to_add
        puts "Tag #{tag_to_add} already exists"
        uncached_buildpack = Dir["../pivotal-buildpack/*.zip"].first
        cached_buildpack = Dir["../pivotal-buildpack-cached/*.zip"].first

        output_uncached = File.join('..', 'buildpack-artifacts', File.basename(uncached_buildpack))
        output_cached = File.join('..', 'buildpack-artifacts', File.basename(cached_buildpack))

        FileUtils.mv(uncached_buildpack, output_uncached)
        FileUtils.mv(cached_buildpack, output_cached)
      else
        stack = ENV.fetch('CF_STACK')
        stack_flag = stack == 'any' ? '--any-stack' : "--stack=#{stack}"
        puts `git tag #{tag_to_add}`
        if File.exists?('compile-extensions')
          system(<<~EOF)
                  export BUNDLE_GEMFILE=cf.Gemfile
                  if [ ! -z "$RUBYGEM_MIRROR" ]; then
                    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
                  fi
                  bundle install
                  bundle exec buildpack-packager --uncached #{stack_flag}
                  bundle exec buildpack-packager --cached #{stack_flag}
                  echo "stack: #{stack}" >> manifest.yml
                  zip *-cached*.zip manifest.yml
                  EOF
        else
          system(<<~EOF)
                  export GOPATH=$PWD
                  export GOBIN=$GOPATH/.bin
                  export PATH=$GOBIN:$PATH
                  (cd src/*/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager && go install)
                  ./.bin/buildpack-packager build --cached=false #{stack_flag}
                  ./.bin/buildpack-packager build --cached=true #{stack_flag}
                  EOF
        end

        timestamp = `date +%s`.strip

        Dir.mkdir("../buildpack-artifacts/uncached")
        Dir.mkdir("../buildpack-artifacts/cached")
        Dir["*.zip"].map do |filename|
          filename.match(/(.*)_buildpack(-cached)?.*-v(.*).zip/) do |match|
            language = match[1]
            cached = match[2]
            version = match[3]
            stack_string = stack != 'any' ? "-#{stack}" : ''
            dir = cached ? 'cached' : 'uncached'

            output_file = "../buildpack-artifacts/#{dir}/#{language}_buildpack#{cached}#{stack_string}-v#{version}+#{timestamp}.zip"

            FileUtils.mv(filename, output_file)
          end
        end

        Dir.chdir('../buildpack-artifacts') do
          Dir["*/*.zip"].each do |buildpack|
            md5sum = `md5sum #{buildpack}`
            sha256sum = `sha256sum #{buildpack}`
            puts "md5: #{md5sum}"
            puts "sha256: #{sha256sum}"
          end
        end
      end
    end
  end
end
