require 'json'
require 'open3'

class Commit
  attr_reader :commit, :subject, :body

  def initialize(hash)
    @commit = hash['commit']
    @subject = hash['subject']
    @body = []

    hash['body'].to_s.split("\n").each do |line|
      case line
      when /^Signed-off-by:|^Co-authored-by:/
      else
        @body << line
      end
    end
    @body.pop while @body.last =~ /^\s*$/
  end

  def to_s
    s = ["* #{subject}"]
    s += @body.map { |s| s.gsub(/^(.*)/, '  \1') } if @body.size.positive?
    s.join("\n")
  end

  def self.recent(old_version)
    cmd = %(git log --pretty=format:'%H')
    cmd += " v#{old_version}..HEAD" if (old_version != '0.0.0') && !old_version.nil?
    hashes, = Open3.capture2(cmd)
    hashes.split("\n").map do |hash|
      commit, = Open3.capture2(%(git log --pretty=format:'{"commit": "%H", "subject": "%s", "body": "%b"}' -n 1 #{hash}))
      commit.gsub!("\n", '\n')
      c = JSON.parse(commit)
      Commit.new(c)
    rescue StandardError
      commit, = Open3.capture2(%(git log -n 1 #{hash}))
      commit
    end
  end
end
