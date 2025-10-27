require 'digest'
require 'fileutils'

class BuildpackFinalizer
  def initialize(artifact_dir, version, buildpack_repo_dir, uncached_buildpack_dirs)
    @artifact_dir = artifact_dir
    @version = version
    @buildpack_repo_dir = buildpack_repo_dir
    @uncached_buildpack_dirs = uncached_buildpack_dirs
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
      return unless File.exist?('CHANGELOG')

      changes = File.read('CHANGELOG')
      recent_changes = changes.split(/^v[0-9.]+.*?=+$/m)[1]&.strip

      File.write(@recent_changes_file, "#{recent_changes}\n") if recent_changes
    end
  end

  def add_dependencies
    Dir.chdir(@buildpack_repo_dir) do
      go_mod_file = File.file?('go.mod')
      if go_mod_file
        Dir.chdir('/tmp') do
          `go install github.com/cloudfoundry/libbuildpack/packager/buildpack-packager@latest`
        end
        File.write(@recent_changes_file, `buildpack-packager summary`, mode: 'a')
      else
        num_cores = `nproc`
        system("BUNDLE_GEMFILE=cf.Gemfile bundle install --jobs=#{num_cores} --deployment")
        system('BUNDLE_GEMFILE=cf.Gemfile bundle cache')

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
    puts "DEBUG: Processing uncached buildpack directories: #{@uncached_buildpack_dirs}"
    @uncached_buildpack_dirs.each do |uncached_buildpack_dir|
      puts "DEBUG: Processing directory: #{uncached_buildpack_dir}"
      Dir.chdir(uncached_buildpack_dir) do
        zip_files = Dir.glob('*.zip')
        puts "DEBUG: Found zip files in #{uncached_buildpack_dir}: #{zip_files}"
        zip_files.map do |filename|
          puts "DEBUG: Processing file: #{filename}"
          puts "DEBUG: Looking for pattern: /(.*)_buildpack(-.*)?-v#{@version}\\+.*.zip/"
          filename.match(/(.*)_buildpack(-.*)?-v#{@version}\+.*.zip/) do |match|
            puts "DEBUG: Pattern matched! #{match.to_a}"
            _, language, stack_string = match.to_a
            new_filename = "#{language}-buildpack#{stack_string}-v#{@version}.zip"
            new_path     = File.join(@artifact_dir, new_filename)
            puts "DEBUG: Moving #{filename} to #{new_path}"

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
