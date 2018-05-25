class Dependencies
  def initialize(dep, line, removal_strategy, dependencies, master_dependencies)
    @dep = dep
    @line = line
    @removal_strategy = removal_strategy
    @dependencies = dependencies
    @matching_deps = dependencies.select do |d|
      d['name'] == @dep['name'] && same_line?(d['version'])
    end
    @master_dependencies = master_dependencies
  end

  def switch
    out = @dependencies
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
      version = Gem::Version.new(d['version']) rescue d['version']
      [ d['name'], version ]
    end
  end

  private

  def latest?
    @matching_deps.all? do |d|
      Gem::Version.new(@dep['version']) > Gem::Version.new(d['version'])
    end
  end

  def same_line?(version)
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
      d['name'] == @dep['name'] && same_line?(d['version'])
    end.sort_by { |d| Gem::Version.new(d['version']) rescue d['version'] }.last
    dep ? [dep] : []
  end
end
