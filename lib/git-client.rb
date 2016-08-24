require 'open3'

class GitClient
  class GitError < StandardError;end

  def self.last_commit_message(dir, previous = 0)
    Dir.chdir(dir) do
      command = "git log --format=%B -n 1 HEAD~#{previous}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get last commit message. STDERR was: #{stderr_str}") unless status.success?

      stdout_str
    end
  end

  def self.last_commit_author(dir, previous = 0)
    Dir.chdir(dir) do
      command = "git log -n 1 HEAD~#{previous}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise "Could not get last commit message. STDERR was: #{stderr_str}" unless status.success?

      stdout_str.match /Author: (.*) </
      $1
    end
  end

  def self.set_global_config(option, value)
    raise "Could not set #{option} to #{value}" unless system("git config --global #{option} \"#{value}\"")
  end

  def self.add_everything
    raise GitError.new('Could not add files') unless system('git add -A')
  end

  def self.add_file(filename)
    raise GitError.new("Could not add file: #{filename}") unless system("git add #{filename}")
  end

  def self.safe_commit(message)
    changes_staged_for_commit = !system('git diff --cached --exit-code')

    if changes_staged_for_commit
      raise GitError.new('Commit failed') unless system("git commit -m '#{message}'")
    else
      puts 'No staged changes were available to commit, doing nothing.'
    end
  end

  def self.git_tag_shas(dir)
    Dir.chdir(dir) do
      command = 'git ls-remote --tags'
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get git tag shas. STDERR was: #{stderr_str}") unless status.success?

      stdout_str.split("\n").map(&:split).map(&:first)
    end
  end

  def self.get_file_contents_at_sha(dir, sha, file)
    Dir.chdir(dir) do
      command = "git show #{sha}:#{file}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not show #{file} at #{sha}. STDERR was: #{stderr_str}") unless status.success?

      stdout_str
    end
  end
end
