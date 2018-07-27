# encoding: utf-8
require 'digest'
require 'fileutils'

class BuildpackFinalizer

  def initialize(artifact_dir, version, buildpack_repo_dir, uncached_buildpack_dirs)
    @artifact_dir = artifact_dir
    @version = version
    @buildpack_repo_dir = buildpack_repo_dir
    @uncached_buildpack_dir = uncached_buildpack_dirs
    @recent_changes_file = File.join(artifact_dir, 'RECENT_CHANGES')
  end

  def run
    write_tag
    add_changelog
    add_dependencies
    move_uncached_buildpack
  end

  private

  def write_tag
    File.write(File.join(@artifact_dir, 'tag'), "v#{@version}")
  end

  def add_changelog
    Dir.chdir(@buildpack_repo_dir) do
      changes       = File.read('CHANGELOG')
      recent_changes = changes.split(/^v[0-9\.]+.*?=+$/m)[1].strip

      File.write(@recent_changes_file, "#{recent_changes}\n")
    end
  end

  def add_dependencies
    Dir.chdir(@buildpack_repo_dir) do
      go_packager = Dir.glob("src/*/vendor/github.com/cloudfoundry/libbuildpack/packager/buildpack-packager").first
      if go_packager
        Dir.chdir(go_packager) do
          `go install`
        end
        File.write(@recent_changes_file, `buildpack-packager summary`, mode: 'a')
      else
        num_cores = `nproc`
        system("BUNDLE_GEMFILE=cf.Gemfile bundle install --jobs=#{num_cores}")

        File.write(@recent_changes_file, [
          "\n\nPackaged binaries:\n",
          `BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --list`,
          "Default binary versions:\n",
          `BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --defaults`
        ].join("\n"), mode: 'a')
      end
    end
  end

  def move_uncached_buildpack
    @uncached_buildpack_dirs.each do |uncached_buildpack_dir|
      Dir.chdir(uncached_buildpack_dir) do
        Dir.glob('*.zip').map do |filename|
          filename.match(/(.*)_buildpack(-.*)?-v#{@version}\+.*.zip/) do |match|
            _, language, stack_string  = match.to_a
            new_filename = "#{language}-buildpack#{stack_string}-v#{@version}.zip"
            new_path     = File.join(@artifact_dir, new_filename)

            FileUtils.mv(filename, new_path)

            shasum = Digest::SHA256.file(new_path).hexdigest

            # append SHA to RELEASE NOTES
            File.write(@recent_changes_file, "  * Uncached buildpack SHA256: #{shasum}\n", mode: 'a')
            File.write("#{new_path}.SHA256SUM.txt", "#{shasum}  #{new_filename}")
          end
        end
      end
    end
  end
end
