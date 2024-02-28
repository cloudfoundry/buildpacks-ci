require 'json'
require 'open-uri'
require 'uri'

class UsnReleaseNotes
  attr_reader :usn_id, :usn_title, :usn_url

  def initialize(usn_id)
    @usn_id = usn_id.upcase
    @usn_url = "https://ubuntu.com/security/notices/#{@usn_id}"
    @usn_api_url = "https://ubuntu.com/security/notices/#{@usn_id}.json"
    @usn_data = fetch_usn_data
    @usn_title = @usn_data['title']
  end

  def text
    @text ||= release_note_text
  end

  private

  def fetch_usn_data
    JSON.parse(URI.open(@usn_api_url).read)
  end

  def release_note_text
    cves = @usn_data['cves'] || []
    lps = @usn_data['lps'] || []

    raise "Could not find CVE or LP references for release notes (usn url: #{@usn_url})" if (cves.empty? && lps.empty?)

    notes = "[#{@usn_id}](#{@usn_url}) #{@usn_title}:\n"

    cves.each do |cve|
      cve_id = cve['id']
      cve_description = cve['description'] || 'Nothing found in description'
      cve_url = "https://ubuntu.com/security/#{cve_id}"

      notes += "* [#{cve_id}](#{cve_url}): #{cve_description}\n"
    end

    lps.each do |lp|
      lp_id = lp['id']
      lp_description = lp['description'] || 'Could not get description'

      notes += "* [#{lp_id}](#{lp['url']}): #{lp_description}\n"
    end

    notes
  end
end
