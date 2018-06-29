class Dependencies
  def initialize(dep, line, removal_strategy, dependencies, master_dependencies)
    @dep = dep
    @line = line
    @removal_strategy = removal_strategy
    @dependencies = dependencies
    @matching_deps = dependencies.select do |d|
      same_dependency_line?(d['version'], d['name'])
    end
    @master_dependencies = master_dependencies
  end

  def switch
    out = @dependencies
    puts "version is #{@dep['version']}"
    puts "matching_deps are #{@matching_deps.map { |d| d['version'] }}"
    if @matching_deps.map{|d|d['version']}.include?(@dep['version'])
      out = ((@dependencies.reject { |d| d['version'] == @dep['version'] }) + [@dep])
    elsif @removal_strategy == 'keep_all'
      out = @dependencies + [@dep]
    elsif latest?
      out = ((@dependencies - @matching_deps) + [@dep] + master_dependencies)
    else
      return @dependencies
    end
    out.sort_by do |d|
      version = d['version']
      version = version[1..-1] if !version.nil? && version.start_with?('v')
      version = Gem::Version.new(version) rescue version
      [ d['name'], version ]
    end
  end

  private

  def latest?
    @matching_deps.all? do |d|
      Gem::Version.new(@dep['version']) > Gem::Version.new(d['version'])
    end
  end

  def same_dependency_line?(version, dep_name)
    return false if dep_name != @dep['name']
    return false if @dep['name'] == 'dotnet' && version == '2.1.201' && @dep['version'] != '2.1.201'

    version = begin
      Gem::Version.new(version)
    rescue
      return false
    end

    case @line
    when 'major'
      version.segments[0] == Gem::Version.new(@dep['version']).segments[0]
    when 'minor'
      version.segments[0,2] == Gem::Version.new(@dep['version']).segments[0,2]
    when nil, '', 'null'
      true
    else
      raise "Unknown version line specifier: #{@line}"
    end
  end

  def master_dependencies
    return [] unless @removal_strategy == 'keep_master'
    dep = @master_dependencies.select do |d|
      same_dependency_line?(d['version'], d['name'])
    end.sort_by { |d| Gem::Version.new(d['version']) rescue d['version'] }.last
    dep ? [dep] : []
  end
end
