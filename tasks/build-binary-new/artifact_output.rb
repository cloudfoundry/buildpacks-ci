class ArtifactOutput
  attr_reader :base_dir

  def initialize(base_dir = 'artifacts')
    @base_dir = base_dir
  end

  def move_dependency(name, old_file_path, filename_prefix, ext)
    sha      = Digest::SHA256.hexdigest(open(old_file_path).read)
    filename = "#{filename_prefix}-#{sha[0..7]}.#{ext}"
    FileUtils.mv(old_file_path, File.join(@base_dir, filename))
    {
      sha256: sha,
      url:    "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{filename}"
    }
  end
end