require 'json'
require 'nokogiri'
require 'open-uri'

class DeleteUnaffectedStories
  attr_reader :stories

  def initialize(stories_file, stack_receipt, output_file)
    ref = JSON.parse(File.read(stories_file))
    @stories = JSON.parse(ref['version']['ref'])
    @receipt = File.read(stack_receipt)
    @output_file = output_file
  end

  def run
    any_failed = false
    output = {}
    stories.each do |story|
      begin
        affected = packages(story).any? do |package|
          @receipt.include? package
        end
        output[story['ref']] = affected ? 'affected' : 'delete'
      rescue
        puts 'IGNORED: ', story.to_hash
        any_failed = true
      end
    end

    File.write(@output_file, JSON.dump(output))
    raise "Some stories failed" if any_failed
  end

  private

  def packages(story)
    packages = []
    trusty = false
    story['description'].split(/\n/).each do |line|
      case
      when line =~ /^\*\*Trusty Packages:\*\*/
        trusty = true
      when line =~ /^\s*$/
        trusty = false
      when trusty == true
        packages << line.split.first
      end
    end
    packages
  end
end
