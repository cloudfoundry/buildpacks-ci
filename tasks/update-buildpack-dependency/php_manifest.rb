class PHPManifest
  def self.update_defaults(manifest, source_name, resource_version)
    manifest['default_versions'].map do |default|
      if default['name'] == source_name
        default['version'] = resource_version
      end
      default
    end
  end
end
