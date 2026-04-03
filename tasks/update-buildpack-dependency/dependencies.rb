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
      puts "DEBUG Dependencies.switch: Rebuilding existing version #{@dep['version']}"
      out = (@dependencies.reject { |d| same_dependency_line?(d['cf_stacks'], d['version'], d['name']) && d['version'] == @dep['version'] } + [@dep])
    # adding a new one, but keep everything
    elsif @removal_strategy == 'keep_all'
      puts "DEBUG Dependencies.switch: Keep all strategy"
      out = @dependencies + [@dep]
    # adding one newer than all existing versions
    elsif latest?
      puts "DEBUG Dependencies.switch: Latest version, removal_strategy=#{@removal_strategy}"
      puts "DEBUG Dependencies.switch: @matching_deps count=#{@matching_deps.length}, versions=#{@matching_deps.map { |d| [d['version'], d['cf_stacks']] }.inspect}"
      puts "DEBUG Dependencies.switch: Adding dep version=#{@dep['version']}, stacks=#{@dep['cf_stacks'].inspect}"
      # keep deps (from latest released buildpack) and add this new one. If removal_strategy is NOT keep_latest_released do not keep any deps from latest released buidpack.
      out = ((@dependencies - @matching_deps) + [@dep] + dependencies_latest_released)
      puts "DEBUG Dependencies.switch: Result has #{out.select { |d| d['name'] == @dep['name'] && d['version'] == @dep['version'] }.length} entries for #{@dep['name']} #{@dep['version']}"
    else
      puts "DEBUG Dependencies.switch: Not adding (not latest)"
      # if not newer, don't do anything
      return @dependencies
    end
    out.sort_by do |d|
      version = d['version']
      # Ensure version is a string (YAML may parse numbers like 11.0 as Float)
      version = version.to_s unless version.nil?
      version = version[1..] if !version.nil? && version.start_with?('v')
      # SemVer.parse returns nil (not an exception) for unparseable versions.
      # Try padding 2-part versions like "25.2" to "25.2.0" for SemVer compatibility.
      version = SemVer.parse(version) || SemVer.parse("#{version}.0") || version
      [d['name'], version, d['cf_stacks']]
    end
  end

  private

  def latest?
    puts "DEBUG latest?: Checking if #{@dep['version']} (#{@dep['cf_stacks'].inspect}) is latest"
    puts "DEBUG latest?: @matching_deps: #{@matching_deps.map { |d| [d['version'], d['cf_stacks']] }.inspect}"
    result = @matching_deps.all? do |d|
      new_ver = SemVer.parse(@dep['version'])
      old_ver = SemVer.parse(d['version'])
      puts "DEBUG latest?: Comparing #{@dep['version']} (#{new_ver.inspect}) vs #{d['version']} (#{old_ver.inspect}) for stacks #{d['cf_stacks'].inspect}"
      
      # If SemVer parsing fails or produces equal results for what should be different versions
      # (e.g., 4-part versions like 1.29.2.3 vs 1.29.2.1 both parse as 1.29.2),
      # fall back to Gem::Version which handles arbitrary version part counts
      if new_ver.nil? || old_ver.nil? || (new_ver == old_ver && @dep['version'] != d['version'])
        puts "DEBUG latest?: SemVer failed or equal, using Gem::Version fallback"
        new_ver_gem = Gem::Version.new(@dep['version'])
        old_ver_gem = Gem::Version.new(d['version'])
        is_greater = new_ver_gem > old_ver_gem
        puts "DEBUG latest?: Gem::Version: #{new_ver_gem} > #{old_ver_gem} = #{is_greater}"
        next is_greater
      end

      is_greater = new_ver > old_ver
      puts "DEBUG latest?: #{new_ver} > #{old_ver} = #{is_greater}"
      is_greater
    end
    puts "DEBUG latest?: Result = #{result}"
    result
  end

  # When rebuilding, we don't want to lose supported stacks
  # [1,2,3], [1,2] => false
  # [1,2,3], [1,2,3] => true
  # [1], [1,2] => true
  def dep_includes_at_least_these_stacks?(manifest_stacks)
    manifest_stacks.nil? or (manifest_stacks - @dep['cf_stacks']).empty?
  end

  # Returns true when the incoming dep is an any-stack build (covers multiple stacks).
  # Any-stack deps produce a single manifest entry per version regardless of which
  # stacks are listed — the set of stacks can change across builds as new stacks are
  # introduced (e.g. cflinuxfs3+cflinuxfs4 → cflinuxfs4+cflinuxfs5).
  # URI pattern for any-stack deps contains "any-stack" in the filename.
  def any_stack_dep?
    @dep['uri']&.include?('any-stack')
  end

  def same_dependency_line?(stacks, version, dep_name)
    return false if dep_name != @dep['name']
    # For any-stack deps, match solely on name+version — the stack set is irrelevant.
    # This prevents duplicate entries when the supported stacks change between builds.
    # Stack-specific deps legitimately have one entry per stack for the same version,
    # so they still require the stack subset check.
    return false unless any_stack_dep? || dep_includes_at_least_these_stacks?(stacks)

    parsed_version = SemVer.parse(version.to_s)
    return false if parsed_version.nil?

    dep_version = SemVer.parse(@dep['version'].to_s)
    return false if dep_version.nil?

    case @line
    when 'major'
      parsed_version.major == dep_version.major
    when 'minor'
      [parsed_version.major, parsed_version.minor] == [dep_version.major, dep_version.minor]
    when 'nginx'
      # 1.13.X and 1.15.X are the same version line
      # 1.12.X and 1.14.X are the same version line
      parsed_version.major == dep_version.major &&
        parsed_version.minor.even? == dep_version.minor.even?
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
    end.max_by do |d|
      SemVer.parse(d['version'])
    rescue StandardError
      d['version']
    end
    dep ? [dep] : []
  end
end
