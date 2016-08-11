require 'open3'

class GitClient
  def self.last_commit_message(dir)
    Dir.chdir(dir) do
      command = 'git log --format=%B -n 1 HEAD'
      stdout_str, stderr_str, status = Open3.capture3(command)

      raise "Could not get last commit message. STDERR was: #{stderr_str}" unless status.success?

      stdout_str
    end
  end

  def self.add_everything
    raise 'Could not add files' unless system('git add -A')
  end
end
