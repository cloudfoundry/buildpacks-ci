class BuildInput
  attr_reader :tracker_story_id, :url

  def initialize(tracker_story_id, url = nil)
    @tracker_story_id = tracker_story_id
    @url = url
  end

  def self.from_file(build_file)
    data = JSON.parse(File.open(build_file).read)
    BuildInput.new(
      data['tracker_story_id'] || '',
      data['url']
    )
  end

  def copy_to_build_output
    system('rsync -a builds/ builds-artifacts/') or raise('Could not copy builds to builds artifacts')
  end
end
