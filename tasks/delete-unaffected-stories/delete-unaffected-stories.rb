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
    url = story['description'].match(/^\**USN:\**\s*(\S+)$/)[1]
    url.gsub!(/^http:/, 'https:')
    doc = Nokogiri::HTML(open(url))
    node = doc.css('dt:contains("Ubuntu 14.04 LTS")').first&.next_sibling
    while %w(text dd).include? node&.name
      if node.name == 'dd'
        packages << node.css('> a').text
      end
      node = node.next_sibling
    end
    packages
  end
end
