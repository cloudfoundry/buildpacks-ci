class GitClient
  def last_commit_message(dir)
    Dir.chdir(dir) { `git log --format=%B -n 1 HEAD` }
  end
end
