class SemanticVersion
  include Comparable(self)

  getter original : String
  getter major : Int32
  getter minor : Int32
  getter patch : Int32
  getter metadata : String | Nil

  def initialize(@original : String)
    m = @original.match /^v?(\d+)(\.(\d+))?(\.(\d+))?(.+)?/
    if m
      @major = m[1].to_i
      @minor = m[3]? ? m[3].to_i : 0
      @patch = m[5]? ? m[5].to_i : 0
      @metadata = m[6]? ? m[6] : nil
    else
      raise ArgumentError.new("Not a semantic version: #{@original.inspect}")
    end
  end

  def <=>(other : self) : Int32
    r = major <=> other.major
    return r if r != 0
    r = minor <=> other.minor
    return r if r != 0
    r = patch <=> other.patch
    return r if r != 0

    original <=> other.original
  end

  def is_final_release? : Bool
    !metadata
  end
end

# NOTE: Keep in sync with 'tasks/build-binary-new/create-new-version-line-story.rb'!
class SemanticVersionFilter
  def initialize(@filter_string : String)
  end

  def match(semver : SemanticVersion) : Bool
    semver_string : String = "#{semver.major}.#{semver.minor}.#{semver.patch}"
    first_x_idx = @filter_string.index("X")
    if first_x_idx.nil?
      semver_string == @filter_string
    else
      prefix = @filter_string[0, first_x_idx]
      semver_string.starts_with?(prefix) && @filter_string.size <= semver_string.size
    end
  end
end
