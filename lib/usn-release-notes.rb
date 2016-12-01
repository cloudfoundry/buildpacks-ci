require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'

class UsnReleaseNotes

  attr_reader :usn_id, :usn_title

  def initialize(usn_id)
    @usn_id    = usn_id.upcase
    @contents  = open(usn_url).read
    @doc       = Nokogiri::HTML(@contents)
    @usn_title = @doc.css('#main-content > div > h2').first.text
  end

  def text
    @text ||= release_note_text
  end

  private

  def usn_url
    "https://www.ubuntu.com/usn/#{@usn_id}/"
  end

  def release_note_text
    cves      = @doc.css('#main-content > div > h3:contains("References") + p > a[href*="cve/CVE"]')

    notes = "[#{usn_id}](#{usn_url}) #{usn_title}:\n"

    cves.each do |cve|
      cve_id  = cve.text
      cve_uri = cve['href']
      cve_element = Nokogiri::HTML(open(cve_uri, :allow_redirections => :safe).read).css('#container > div:contains("Description") > div.value').first

      cve_description = cve_element.children.map do |child|
        child.text if child.text?
      end.compact.join(" ")

      notes += "* [#{cve_id}](#{cve_uri}): #{cve_description}\n"
    end

    notes
  end
end
