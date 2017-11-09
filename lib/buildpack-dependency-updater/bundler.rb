class BuildpackDependencyUpdater::Bundler < BuildpackDependencyUpdater
  def dependency_version
    @dependency_version ||= dependency_build_info['version'].gsub(/^v/,'')
  end
end
