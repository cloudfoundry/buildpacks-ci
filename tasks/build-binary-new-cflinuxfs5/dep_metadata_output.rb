require 'digest'

class DepMetadataOutput
  attr_reader :base_dir

  def initialize(base_dir = 'dep-metadata')
    @base_dir = base_dir
  end

  def write_metadata(dep_filename, data)
    dep_basename = File.basename(dep_filename)
    metadata_filename = "#{dep_basename}_metadata.json"
    File.write(File.join(@base_dir, metadata_filename), data.to_json)
  end
end
