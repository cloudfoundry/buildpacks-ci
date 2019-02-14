require 'fileutils'
require 'TOML'

class CNBArtifactProducer
  attr_reader :buildpack_dir, :buildpack_name

  def initialize(buildpack_dir, buildpack_name)
    @buildpack_dir  = buildpack_dir
    @buildpack_name = buildpack_name
  end


  def run!
    Dir.chdir(buildpack_dir) do

      #TODO: add tag to
      #replace this with version from buildpack.toml
      bp_toml    = TOML::load_file('buildpack.toml')
      tag_to_add = "v#{bp_toml['buildpack']['version'].strip}"
      puts "Tag to add: #{tag_to_add}"


      # mkdir for source and packaged cnb
      Dir.mkdir('../buildpack-artifacts/source')

      # we have already built this release at least 1 time? AND released it
      # could this also stop blocking?

      #
      system(<<~EOF)
        ./go mod vendor
        ./scripts/install_tools.sh
        ./.bin/package.sh build
      EOF
    end

    FileUtils.mv('/tmp/')

    # don't timestamp just erase everything for now
    # TODO: make this save the last k tests
    # #TODO: add tag_to_add to matched cnb
    #timestamp = `date +%s`.strip
    tmp_path = '/tmp'
    Dir.foreach(tmp_path).each do |filename|
      filename.match(/.*-cnb.*/) do |match|
        FileUtils.mv(File.join(tmp_path, match.to_s), 'buildpack-artifacts/source')
      end
    end


    Dir.foreach('buildpack-artifacts/source') do |filename|
      filename.match(/.*-cnb.*/) do |match|
        md5sum    = `md5sum #{File.join('buildpack-artifacts/source', buildpack)}`
        sha256sum = `sha256sum #{File.join('buildpack-artifacts/source', buildpack)}`
        puts "md5: #{md5sum}"
        puts "sha256: #{sha256sum}"
      end
    end
  end
end
