class GitClient
  def self.last_commit_message(dir)
    Dir.chdir(dir) { `git log --format=%B -n 1 HEAD` }
  end

  def self.add_everything
    raise 'Could not add files' unless system('git add -A')
  end
end
