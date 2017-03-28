require 'yaml'
require 'diffy'

require_relative '../../lib/usn-release-notes.rb'

class ReleaseNotesCreator

  def initialize(cves_yaml_file, old_receipt_file, new_receipt_file)
    @cves_yaml_file = cves_yaml_file
    @old_receipt_file = old_receipt_file
    @new_receipt_file = new_receipt_file
  end

  def cves
    @cves ||= YAML.load_file(@cves_yaml_file)
  end

  def old_receipt
    @old_receipt ||= File.read(@old_receipt_file).split("\n")[7..-1].join("\n")
  end

  def new_receipt
    @new_receipt ||= File.read(@new_receipt_file).split("\n")[7..-1].join("\n")
  end

  def release_notes
    text = ""
    text += usn_release_notes_section + "\n" unless unreleased_usns.count == 0
    text += receipt_diff_section
    text
  end

  def usn_release_notes_section
    text = ""
    text = "Notably, this release addresses:\n\n" unless unreleased_usns.count == 0

    unreleased_usns.each do |usn|
      text += UsnReleaseNotes.new(usn).text + "\n\n"
    end
    text
  end

  def unreleased_usns
    cves.select do |cve|
      cve['stack_release'] == 'unreleased'
    end.map do |cve|
      cve['title'].split(':').first
    end
  end

  def receipt_diff_section
    receipt_diff_array = Diffy::Diff.new(old_receipt, new_receipt).select do |line|
      line.match(/^\+/) || line.match(/^-/)
    end.map do |line|
      line.strip.split("  ").select { |word| word !=""}.map { |word| word.strip }
    end

    receipt_diff = ""
    format = format_string(receipt_diff_array)

    receipt_diff_array.each do |line|
      receipt_diff += (format % line).strip + "\n"
    end

    <<~MARKDOWN
    ```
    #{receipt_diff}```
    MARKDOWN
  end

  private

  def format_string(table)
    num_columns = table.first.length
    format_string = ""

    max_lengths = (0...num_columns).map { 0 }
    min_lengths = (0...num_columns).map { 999 }

    table.each do |row|
      (0...num_columns).each do |i|
        if(row[i].length) > max_lengths[i]
          max_lengths[i] = row[i].length
        end

        if(row[i].length) < min_lengths[i]
          min_lengths[i] = row[i].length
        end
      end
    end

    (0...num_columns).each do |i|
      if max_lengths[i] == min_lengths[i]
        format_string += "%-#{max_lengths[i] + 2}s"
      else
        format_string += "%-#{max_lengths[i] + 1}s"
      end
    end

    format_string
  end
end
