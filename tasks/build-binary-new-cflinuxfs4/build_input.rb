class BuildInput
  attr_reader :url

  def initialize(url = nil)
    @url = url
  end

  def self.from_file(build_file)
    data = JSON.parse(File.open(build_file).read)
    BuildInput.new(
      data['url']
    )
  end

  def copy_to_build_output
    system('rsync -a builds/ builds-artifacts/') or raise('Could not copy builds to builds artifacts')
  end
end
