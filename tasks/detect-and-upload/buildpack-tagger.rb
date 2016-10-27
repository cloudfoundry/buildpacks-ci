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
        puts `git tag #{tag_to_add}`
        system(<<~EOF)
                  export BUNDLE_GEMFILE=cf.Gemfile
                  bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
                  bundle install
                  bundle exec buildpack-packager --uncached
                  bundle exec buildpack-packager --cached
                  EOF

        timestamp = `date +%s`.strip

        Dir["*.zip"].map do |filename|
          filename.match(/(.*)_buildpack(-cached)?-v(.*).zip/) do |match|
            language = match[1]
            cached = match[2]
            version = match[3]

            output_file = "../buildpack-artifacts/#{language}_buildpack#{cached}-v#{version}+#{timestamp}.zip"

            FileUtils.mv(filename, output_file)
          end
        end

        Dir.chdir('../buildpack-artifacts') do
          Dir["*.zip"].each do |buildpack|
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
