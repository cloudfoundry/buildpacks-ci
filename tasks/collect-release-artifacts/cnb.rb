require 'octokit'

class VersionDiff
  attr_accessor :current_version, :versions, :new_cnb

  def initialize(versions)
    @versions = versions
    if versions.first == "new-cnb"
      @new_cnb = true
      @current_version = versions.last
    else
      @new_cnb = false
      @current_version = versions.first
    end
  end

  def include?(version)
    @versions.include? version
  end
end

class CNB
  class << self
    def name_and_url(id)
      cnb_name = id.split('.').last
      if id.start_with? "org.cloudfoundry"
        name = "#{cnb_name}-cnb"
        url  = "cloudfoundry/#{name}"
      elsif id.start_with? "io.pivotal"
        name = "p-#{cnb_name}-cnb"
        url = "pivotal-cf/#{name}"
      elsif id.start_with? "lifecycle"
        name = id
        url = "buildpack/#{name}"
      else
        raise "unknown cnb path"
      end
      [name, url]
    end
  end

  attr_accessor :name, :version, :url

  def initialize(id, version_diff, oktokit = Octokit)
    set_name_and_url(id)
    @version_diff = VersionDiff.new(version_diff)
    @version = @version_diff.current_version
    @oktokit = oktokit
  end

  def release_notes
    if @version_diff.new_cnb
      "### Added version #{@version}"
    else
      release_notes_map = releases.map do | release | <<~NOTES
### #{release.name}
#{clean_release_notes(release.body)}

#{more_details(release)}
NOTES
      end
      release_notes_map.join("\n")
    end
  end

  def dependencies
    body = releases[0].body
    idx = body.index("Packaged binaries")
    if idx
      fin_idx = body.index("Supported stacks") || body.length
      body[idx...fin_idx]
    else
      ""
    end
  end

  def stacks
    body = releases[0].body
    idx = body.index("Supported stacks") || body.length
    body[idx..-1]
  end

  private

  def clean_release_notes(release_body)
    if release_body.include? "No major changes"
      return ""
    end
    release_body
      .split('Packaged binaries:')[0]
      .split('Supported stacks:')[0]
      .strip
  end

  def more_details(release)
    "More details are [here](#{release.html_url})."
  end

  def releases
    @releases ||= @oktokit.releases(@url).select{|release| @version_diff.include? release.tag_name}
  end

  def set_name_and_url(id)
    @name, @url = CNB.name_and_url(id)
  end
end