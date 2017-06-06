# encoding: utf-8
require 'digest'
require 'fileutils'

class BuildpackFinalizer

  def initialize(artifact_dir, version, buildpack_repo_dir, uncached_buildpack_dir)
    @artifact_dir = artifact_dir
    @version = version
    @buildpack_repo_dir = buildpack_repo_dir
    @uncached_buildpack_dir = uncached_buildpack_dir
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

  def move_uncached_buildpack
    Dir.chdir(@uncached_buildpack_dir) do
      Dir.glob('*.zip').map do |filename|
        filename.match(/(.*)_buildpack-v#{@version}\+.*.zip/) do |match|
          _, language  = match.to_a
          new_filename = "#{language}-buildpack-v#{@version}.zip"
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
