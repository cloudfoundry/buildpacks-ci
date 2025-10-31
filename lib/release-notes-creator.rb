require 'yaml'
require 'date'
require 'time'
require 'diffy'
require_relative 'usn-release-notes'

class RootfsReleaseNotesCreator
  def initialize(cves_yaml_file, old_receipt_file, new_receipt_file)
    @cves_yaml_file = cves_yaml_file
    @old_receipt_file = old_receipt_file
    @new_receipt_file = new_receipt_file
  end

  def cves
    @cves ||= YAML.load_file(@cves_yaml_file, permitted_classes: [Date, Time])
  end

  def release_notes
    text = ''
    text += "#{usn_release_notes_section}\n" unless unreleased_usns.empty?
    text += receipt_diff_section
    text
  end

  def usn_release_notes_section
    text = ''
    text += "Notably, this release addresses:\n\n" unless unreleased_usns.empty?
    unreleased_usns.each do |usn|
      text += "#{detailed_cve_information(usn)}\n\n"
    rescue Exception => e
      puts "Error fetching USN detailed information #{usn}: #{e.message}"
      text += "#{simple_cve_information(usn)}\n\n"
    end
    text
  end

  def detailed_cve_information(usn)
    UsnReleaseNotes.new(usn).text
  end

  def simple_cve_information(usn)
    "* [#{usn}](https://ubuntu.com/security/notices/#{usn}/)"
  end

  def unreleased_usns
    cves.select { |cve| cve['stack_release'] == 'unreleased' }
        .map { |cve| cve['title'].split(':').first }
  end

  def receipt_diff_section
    diffy = Diffy::Diff.new(@old_receipt_file, @new_receipt_file, source: 'files', diff: '-b') or raise 'Could not create Diffy::Diff'
    receipt_diff_array = parse_diffy_output(diffy)
    receipt_diff = format_diff(receipt_diff_array) unless receipt_diff_array.empty?
    if receipt_diff
      "```\n#{receipt_diff}```\n"
    else
      ''
    end
  end

  def new_packages?
    !receipt_diff_section.empty?
  end

  private

  def parse_diffy_output(diffy)
    diffy.map { |line| line.split(/\s+/, 6).map(&:strip) }
         .select { |arr| arr.length == 6 }
         .map do |arr|
      if arr[0] == '<'
        arr[1] = "-#{arr[1]}"
      else
        arr[0] == '>' ? arr[1] = "+#{arr[1]}" : nil
      end
      arr.shift
      arr
    end
  end

  def format_diff(table)
    format_string = calculate_format_string(table)
    table.map { |line| (format_string % line).strip }.join("\n")
  end

  def calculate_format_string(table)
    num_columns = table.first.length
    max_lengths = (0...num_columns).map { |i| table.map { |row| row[i].length }.max }
    max_lengths.map { |length| length == max_lengths.min ? "%-#{length + 2}s" : "%-#{length + 1}s" }.join
  end
end
