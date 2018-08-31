require 'open3'

class GitClient
  class GitError < StandardError;end

  def self.update_submodule_to_latest(source_dir, dir_to_update)
    latest_ref = GitClient.get_commit_sha(source_dir, 0)

    GitClient.fetch(dir_to_update)

    Dir.chdir(dir_to_update) do
      GitClient.checkout(latest_ref)
    end
  end

  def self.get_commit_sha(dir, number_commits_before_head)
    Dir.chdir(dir) do
      command = "git rev-parse HEAD~#{number_commits_before_head}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get commit SHA for HEAD~#{number_commits_before_head}. STDERR was: #{stderr_str}") unless status.success?

      stdout_str
    end
  end

  def self.last_commit_message(dir, previous = 0, file = nil)
    Dir.chdir(dir) do
      command = "git log --format=%B -n 1 HEAD~#{previous}"
      command += " #{file}" unless file.nil?

      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get commit message for HEAD~#{previous}. STDERR was: #{stderr_str}") unless status.success?

      stdout_str
    end
  end

  def self.last_commit_author(dir, previous = 0)
    Dir.chdir(dir) do
      command = "git log -n 1 HEAD~#{previous}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get author of commit HEAD~#{previous}. STDERR was: #{stderr_str}") unless status.success?

      stdout_str.match /Author: (.*) </
      $1
    end
  end

  def self.last_commit_files(dir)
    Dir.chdir(dir) do
      command = "git log --pretty=\"format:\" --name-only -n 1 HEAD~0"

      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get commit files for HEAD~0. STDERR was: #{stderr_str}") unless status.success?

      stdout_str
    end
  end

  def self.set_global_config(option, value)
    raise GitError.new("Could not set global config #{option} to #{value}") unless system("git config --global #{option} \"#{value}\"")
  end

  def self.add_everything
    raise GitError.new('Could not add files') unless system('git add -A')
  end

  def self.add_file(filename)
    raise GitError.new("Could not add file: #{filename}") unless system("git add #{filename}")
  end

  def self.tag_commit(tag, commit_sha)
    raise GitError.new("Could not tag #{commit_sha} with #{tag}") unless system("git tag -a #{tag} #{commit_sha}")
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

  def self.get_list_of_one_line_commits(dir, number)
    Dir.chdir(dir) do
      command = "git log --oneline -#{number}"
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get last #{number} commits. STDERR was: #{stderr_str}") unless status.success?

      stdout_str.split("\n")
    end
  end

  def self.get_current_branch(dir)
    Dir.chdir(dir) do
      command = 'git rev-parse --abbrev-ref HEAD'
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise GitError.new("Could not get current branch. STDERR was: #{stderr_str}") unless status.success?

      stdout_str.strip
    end
  end

  def self.checkout(branch)
    raise GitError.new("Could not checkout branch: #{branch}") unless system("git checkout #{branch}")
  end

  def self.cherry_pick(commit)
    raise GitError.new("Could not cherry_pick commit: #{commit}") unless system("git cherry-pick #{commit}")
  end

  def self.pull_current_branch
    raise GitError.new('Could not pull branch') unless system('git pull -r')
  end

  def self.clone_repo(url, dir)
    raise GitError.new('Could not clone') unless system("git clone #{url} #{dir}")
  end

  def self.fetch(dir)
    Dir.chdir(dir) do
      raise GitError.new('Could not fetch') unless system('git fetch')
    end
  end
end
