require 'yaml'
require 'diffy'

require_relative 'usn-release-notes'

class ReleaseNotesCreator

  def initialize(cves_yaml_file, old_receipt_file, new_receipt_file)
    @cves_yaml_file = cves_yaml_file
    @old_receipt_file = old_receipt_file
    @new_receipt_file = new_receipt_file
  end

  def cves
    @cves ||= YAML.load_file(@cves_yaml_file)
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
    diffy = Diffy::Diff.new(@old_receipt_file, @new_receipt_file, source: 'files', diff: '-b') or raise 'Could not create Diffy::Diff'
    receipt_diff_array = diffy.map do |line|
      line.split(/\s+/, 6).map(&:strip)
    end.select do |arr|
      arr.length == 6
    end.map do |arr|
      if arr[0] == "<"
        arr[1] = "-#{arr[1]}"
      elsif arr[0] == ">">
        arr[1] = "+#{arr[1]}"
      end
      arr.shift
      arr
    end

    receipt_diff = ""

    if !receipt_diff_array.empty?
      format = format_string(receipt_diff_array)

      receipt_diff_array.each do |line|
        receipt_diff += (format % line).strip + "\n"
      end
    end

    <<~MARKDOWN
    ```
    #{receipt_diff}```
    MARKDOWN
  end

  def new_packages?
    return receipt_diff_section != "```\n```\n"
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
