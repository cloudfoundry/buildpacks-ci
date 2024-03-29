class Dependencies
  def initialize(dep, line, removal_strategy, dependencies, dependencies_latest_released)
    @dep = dep
    @line = line
    @removal_strategy = removal_strategy
    @dependencies = dependencies
    @matching_deps = dependencies.select do |d|
      same_dependency_line?(d['cf_stacks'], d['version'], d['name'])
    end
    @dependencies_latest_released = dependencies_latest_released
  end

  def switch
    # if we're rebuilding, replace matching version
    if @matching_deps.map { |d| d['version'] }.include?(@dep['version'])
      out = ((@dependencies.reject { |d| same_dependency_line?(d['cf_stacks'], d['version'], d['name']) && d['version'] == @dep['version'] }) + [@dep])
    # adding a new one, but keep everything
    elsif @removal_strategy == 'keep_all'
      out = @dependencies + [@dep]
    # adding one newer than all existing versions
    elsif latest?
      # keep deps (from latest released buildpack) and add this new one. If removal_strategy is NOT keep_latest_released do not keep any deps from latest released buidpack.
      out = ((@dependencies - @matching_deps) + [@dep] + dependencies_latest_released)
    else
      # if not newer, don't do anything
      return @dependencies
    end
    out.sort_by do |d|
      version = d['version']
      version = version[1..-1] if !version.nil? && version.start_with?('v')
      version = Gem::Version.new(version) rescue version
      [d['name'], version, d['cf_stacks']]
    end
  end

  private

  def latest?
    @matching_deps.all? do |d|
      Gem::Version.new(@dep['version']) > Gem::Version.new(d['version'])
    end
  end

  # When rebuilding, we don't want to lose supported stacks
  # [1,2,3], [1,2] => false
  # [1,2,3], [1,2,3] => true
  # [1], [1,2] => true
  def dep_includes_at_least_these_stacks?(manifest_stacks)
    manifest_stacks.nil? or (manifest_stacks - @dep['cf_stacks']).empty?
  end

  def same_dependency_line?(stacks, version, dep_name)
    return false if dep_name != @dep['name']
    return false unless dep_includes_at_least_these_stacks?(stacks)

    version = begin
      Gem::Version.new(version)
    rescue
      return false
    end

    case @line
    when 'major'
      version.segments[0] == Gem::Version.new(@dep['version']).segments[0]
    when 'minor'
      version.segments[0, 2] == Gem::Version.new(@dep['version']).segments[0, 2]
    when 'nginx'
      # 1.13.X and 1.15.X are the same version line
      # 1.12.X and 1.14.X are the same version line
      dep_version = Gem::Version.new(@dep['version'])
      version.segments[0] == dep_version.segments[0] &&
        version.segments[1].even? == dep_version.segments[1].even?
    when nil, '', 'null'
      true
    else
      raise "Unknown version line specifier: #{@line}"
    end
  end

  def dependencies_latest_released
    return [] unless @removal_strategy == 'keep_latest_released'
    dep = @dependencies_latest_released.select do |d|
      same_dependency_line?(d['cf_stacks'], d['version'], d['name'])
    end.sort_by {|d| Gem::Version.new(d['version']) rescue d['version']}.last
    dep ? [dep] : []
  end
end
