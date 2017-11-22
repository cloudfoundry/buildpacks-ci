class SemanticVersion
  include Comparable(self)

  getter original : String
  getter major : Int32
  getter minor : Int32
  getter patch : Int32

  def initialize(@original : String)
    m = @original.match /^(\d+)\.(\d+)(\.(\d+))?/
    if m
      @major = m[1].to_i
      @minor = m[2].to_i
      if m[4]?
          @patch = m[4].to_i
      else
        @patch = 0
      end
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
end
