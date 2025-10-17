class PHPManifest
  def self.update_defaults(manifest, target_name, resource_version)
    manifest['default_versions'].map do |default|
      if default['name'] == target_name
        if default['name'] == 'nginx'
          # For nginx, we update defaults only when a mainline version updates.
          # Mainline versions are identified by having an odd number as the minor (e.g. 1.27.2)
          default['version'] = resource_version if Gem::Version.new(resource_version).segments[1].odd?
        else
          default['version'] = resource_version
        end
      end
      default
    end
  end
end
