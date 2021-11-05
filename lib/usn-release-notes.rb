require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'

class UsnReleaseNotes

  attr_reader :usn_id, :usn_title

  def initialize(usn_id)
    @usn_id    = usn_id.upcase
    @contents  = open(usn_url).read
    @doc       = Nokogiri::HTML(@contents)
    @usn_title = @doc.css('#main-content h1').first.text
  end

  def text
    @text ||= release_note_text
  end

  private

  def usn_url
    if @usn_id.match(/^LSN-/)
      "https://usn.ubuntu.com/lsn/#{@usn_id.gsub(/^LSN-/, '')}/"
    else
      "https://ubuntu.com/security/notices/#{@usn_id}/"
    end
  end

  def release_note_text
    cves = []
    lps = []
    open(usn_url).each_line do |line|
      if (cve = line.match(%r{.*href="(?<uri>/security/CVE.*)">(?<text>.*)</a.*}))
        cves << cve
      elsif (lp = line.match(%r{.*href="(?<uri>.*launchpad\.net/bugs.*)">(?<text>.*)</li}))
        lps << lp
      end
    end

    raise "Could not find CVE or LP references for release notes (usn url: #{usn_url})" if (cves.empty? && lps.empty?)

    notes = "[#{usn_id}](#{usn_url}) #{usn_title}:\n"

    cves.each do |cve|
      cve_id = cve['text']
      cve_uri = "https://ubuntu.com/#{cve['uri']}"

      cve_body = open(cve_uri, allow_redirections: :safe).read
        .gsub("\n", ' ')
        .gsub('<br />', ' ')
        .gsub('<br>', ' ')
        .gsub('</br>', ' ')
      cve_description = if (match = cve_body.match(%r{Published: <strong.*?<p>(?<description>.*?)</p>}))
                          match['description']
                        else
                          'Nothing found in description'
                        end

      notes += "* [#{cve_id}](#{cve_uri}): #{cve_description}\n"
    end

    lps.each do |lp|
      lp_id          = lp['text']
      lp_uri         = lp['uri']
      lp_description = ''

      begin
        lp_element = Nokogiri::HTML(open(lp_uri, :allow_redirections => :safe).read).css('#edit-title > span').first

        lp_description = lp_element.children.map do |child|
          child.text.strip if child.text?
        end.compact.join(" ")
      rescue
        lp_description = 'Could not get description'
      end

      notes += "* [#{lp_id}](#{lp_uri}): #{lp_description}\n"
    end

    notes
  end
end
