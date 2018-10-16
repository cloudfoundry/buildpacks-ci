class PHPManifest
  def self.update_defaults(manifest, resource_version)
    manifest['default_versions'].map do |default|
      if default['name'] == 'php'
        default['version'] = resource_version
      end
      default
    end
  end
end