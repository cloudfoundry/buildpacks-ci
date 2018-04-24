class SemanticVersion
  include Comparable(self)

  getter original : String
  getter major : Int32
  getter minor : Int32
  getter patch : Int32
  getter metadata : String | Nil

  def initialize(@original : String)
    m = @original.match /^(\d+)\.(\d+)(\.(\d+))?(.+)?/
    if m
      @major = m[1].to_i
      @minor = m[2].to_i
      @patch = m[4]? ? m[4].to_i : 0
      @metadata = m[5]? ? m[5] : nil
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
