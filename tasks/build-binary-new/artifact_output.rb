require 'digest'

class ArtifactOutput
  attr_reader :base_dir

  def initialize(base_dir = 'artifacts')
    @base_dir = base_dir
  end

  def move_dependency(name, old_file_path, filename_prefix)
    sha      = Digest::SHA256.hexdigest(open(old_file_path).read)
    filename = "#{filename_prefix}_#{sha[0..7]}.#{ext(old_file_path)}"
    FileUtils.mv(old_file_path, File.join(@base_dir, filename))
    {
      sha256: sha,
      url:    "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
    }
  end

  private

  def ext(old_file_path)
    extension = File.basename(old_file_path)[/\.((sh|txt|phar|zip|tar\.gz|tar\.xz|tar\.bz2|tgz))$/, 1]
    extension = "tgz" if extension == "tar.gz"
    extension
  end
end
