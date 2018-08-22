class BuildInput
  attr_reader :tracker_story_id

  def initialize(tracker_story_id)
    @tracker_story_id = tracker_story_id
  end

  def self.from_file(build_file)
    data = JSON.parse(open(build_file).read)
    BuildInput.new(data.dig('tracker_story_id') || '')
  end

  def copy_to_build_output
    system('rsync -a builds/ builds-artifacts/') or raise('Could not copy builds to builds artifacts')
  end
end