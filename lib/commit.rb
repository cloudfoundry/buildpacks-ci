require 'json'
require 'open3'

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
      when /^Signed-off-by:/
      when /^\s*\[#(\d+)\]\s*$/
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
    commits, _ = Open3.capture2(%Q{git log --pretty=format:'{"commit": "%H", "subject": "%s", "body": "%b"},' v#{old_version}..HEAD})
    commits = "[" + commits + "{}]"
    commits.gsub!(/\n/,'\n')
    commits.gsub!('"},\n{"',%Q["},\n{"])
    JSON.parse(commits).select do |c|
      c.size>0
    end.map do |c|
      Commit.new(c)
    end
  end
end
