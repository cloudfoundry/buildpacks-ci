require 'json'
require 'open3'

STORY_ID_ANYWHERE = /\s*\[#(\d+)\]\s*/

class Commit
  attr_reader :commit, :subject, :body, :stories
  def initialize(hash)
    @commit = hash['commit']
    @subject = hash['subject']
    @body = []
    @stories = []

    if @subject =~ /\s*\[#(\d+)\]\s*$/
      id = $1
      @stories << "(https://www.pivotaltracker.com/story/show/#{id})"
      @subject.gsub!(/\s*\[##{id}\]\s*$/,'')
    end

    hash['body'].to_s.split(/\n/).each do |line|
      case line
      when /^Signed-off-by:|^Co-authored-by:/
      when STORY_ID_ANYWHERE
        @body << line.gsub!(STORY_ID_ANYWHERE, '')
        @stories << "(https://www.pivotaltracker.com/story/show/#{$1})"
      else
        @body << line
      end
    end
    while @body.last =~ /^\s*$/ do
      @body.pop
    end
  end

  def to_s
    s = ["* #{subject}"]
    s += @body.map{|s|s.gsub(/^(.*)/, '  \1')} if @body.size > 0
    s += @stories.map{|s|s.gsub(/^(.*)/, '  \1')} if @stories.size > 0
    s.join("\n")
  end

  def self.recent(old_version)
    cmd = %Q{git log --pretty=format:'%H'}
    cmd = cmd + " v#{old_version}..HEAD" if old_version != '0.0.0'
    hashes, _ = Open3.capture2(cmd)
    hashes.split(/\n/).map do |hash|
      begin
        commit, _ = Open3.capture2(%Q{git log --pretty=format:'{"commit": "%H", "subject": "%s", "body": "%b"}' -n 1 #{hash}})
        commit.gsub!(/\n/,'\n')
        c = JSON.parse(commit)
        Commit.new(c)
      rescue => e
        commit, _ = Open3.capture2(%Q{git log -n 1 #{hash}})
        commit
      end
    end
  end
end
