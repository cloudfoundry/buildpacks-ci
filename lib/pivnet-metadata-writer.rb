require 'yaml'

class PivnetMetadataWriter

  require_relative 'pivnet-metadata-writer/dotnet-core.rb'
  require_relative 'pivnet-metadata-writer/rootfs-nc.rb'

  def self.create(type, *args)
    raise "Unknown PivNet product" unless const_defined? type
    const_get(type).new(*args)
  end
end
