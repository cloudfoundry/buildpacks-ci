# encoding: utf-8
require 'spec_helper'
require 'fileutils'
require_relative '../../lib/git-client'

describe GitClient do
  let(:source_dir)    { nil }
  let(:dir)           { nil }
  let(:dir_to_update) { nil }

  after do
    FileUtils.rm_rf(source_dir) unless source_dir.nil?
    FileUtils.rm_rf(dir) unless dir.nil?
    FileUtils.rm_rf(dir_to_update) unless dir_to_update.nil?
  end

  describe '#clone_repo' do
    let(:url) { "https://some-url" }
    let(:dir) {Dir.mktmpdir }
    subject { described_class.clone_repo(url, dir) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should git clone' do
        expect(described_class).to receive(:system).with("git clone #{url} #{dir}")

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not cloning' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not clone')
      end
    end
  end

  describe '#update_submodule_to_latest' do
    let(:source_dir)    { Dir.mktmpdir }
    let(:dir_to_update) { Dir.mktmpdir }
    let(:latest_sha)    { "latest_sha" }

    subject { described_class.update_submodule_to_latest(source_dir, dir_to_update) }

    it "should update target repo's submodule to latest submodule sha" do
      expect(GitClient).to receive(:get_commit_sha).with(source_dir, 0).and_return(latest_sha)
      expect(GitClient).to receive(:fetch).with(dir_to_update)
      expect(GitClient).to receive(:checkout).with(latest_sha)

      subject
    end
  end


  describe '#get_commit_sha' do
    let(:dir)                        { Dir.mktmpdir }
    let(:stderr_output)              { 'this should not matter but is here to avoid undefined symbols' }
    let(:commit_sha)                 { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)             { double(:process_status) }
    let(:number_commits_before_head) { 3 }

    subject { described_class.get_commit_sha(dir, number_commits_before_head) }

    before { allow(Open3).to receive(:capture3) }

    context 'git works properly' do
      let(:commit_sha) { 'ffffaaaaaec7c534f0e1c6a295a2450d17f711a1' }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the last git commit message' do
        expect(Open3).to receive(:capture3).with('git rev-parse HEAD~3').and_return([commit_sha, stderr_output, process_status])
        expect(subject).to eq('ffffaaaaaec7c534f0e1c6a295a2450d17f711a1')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to read the commit message' do
        expect(Open3).to receive(:capture3).with('git rev-parse HEAD~3').and_return([commit_sha, stderr_output, process_status])
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get commit SHA for HEAD~3. STDERR was: stderr output')
      end
    end

  end

  describe '#tag_commit' do
    let(:tag)     { 'randomtag' }
    let(:commit)  { '123456' }
    subject { described_class.tag_commit(tag, commit) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should git tag the specified commit' do
        expect(described_class).to receive(:system).with('git tag -a randomtag 123456')

        subject
      end
    end
  end

  describe '#last_commit_message' do
    let(:dir)                 { Dir.mktmpdir }
    let(:last_commit_message) { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.last_commit_message(dir) }

    before { allow(Open3).to receive(:capture3).with('git log --format=%B -n 1 HEAD~0').and_return([last_commit_message, stderr_output, process_status]) }

    context 'git works properly' do
      let(:last_commit_message) { 'I was last committed' }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the last git commit message' do
        expect(subject).to eq('I was last committed')
      end
    end

    context 'for a specific file' do
      let(:last_commit_message) { 'I was last committed' }
      let(:filename)            { 'directory/info.yml' }

      subject { described_class.last_commit_message(dir, 0, filename) }

      before do
        allow(Open3).to receive(:capture3).with('git log --format=%B -n 1 HEAD~0 directory/info.yml').and_return([last_commit_message, stderr_output, process_status])
        allow(process_status).to receive(:success?).and_return(true)
      end


      it 'should return the last git commit message' do
        expect(subject).to eq('I was last committed')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to read the commit message' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get commit message for HEAD~0. STDERR was: stderr output')
      end
    end
  end

  describe '#last_commit_files' do
    let(:dir)                 { Dir.mktmpdir }
    let(:last_commit_files)   { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.last_commit_files(dir) }

    before { allow(Open3).to receive(:capture3).with('git log --pretty="format:" --name-only -n 1 HEAD~0').and_return([last_commit_files, stderr_output, process_status]) }

    context 'git works properly' do
      let(:last_commit_files) { 'file1\nfile2' }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the last git commit message' do
        expect(subject).to eq('file1\nfile2')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to read the commit files' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get commit files for HEAD~0. STDERR was: stderr output')
      end
    end
  end

  describe '#last_commit_author' do
    let(:dir)                 { Dir.mktmpdir }
    let(:last_commit_message) { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.last_commit_author(dir) }

    before { allow(Open3).to receive(:capture3).and_return([last_commit_message, stderr_output, process_status]) }

    context 'git works properly' do
      let(:last_commit_message) { "I was last committed\n Author: Firstname Lastname <flastname@example.com>" }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the name of the author of the last git commit' do
        expect(subject).to eq('Firstname Lastname')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to get the author of the commit' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get author of commit HEAD~0. STDERR was: stderr output')
      end
    end
  end

  describe '#get_current_branch' do
    let(:dir)                 { Dir.mktmpdir }
    let(:current_branch)      { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.get_current_branch(dir) }

    before { allow(Open3).to receive(:capture3).and_return([current_branch, stderr_output, process_status]) }

    context 'git works properly' do
      let(:current_branch) { 'the-current-git-branch' }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the current git branch' do
        expect(subject).to eq('the-current-git-branch')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to get the current branch' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get current branch. STDERR was: stderr output')
      end
    end
  end

  describe '#get_list_of_one_line_commits' do
    let(:dir)                 { Dir.mktmpdir }
    let(:number)              { 3 }
    let(:last_few_commits)    { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.get_list_of_one_line_commits(dir,number) }

    before { allow(Open3).to receive(:capture3).and_return([last_few_commits, stderr_output, process_status]) }

    context 'git works properly' do
      let(:last_few_commits)    { "7652882 recent commit 1\n34e6f44 recent commit 2\n0b5a735 recent commit 3\n" }

      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should be an array of size 3' do
        expect(subject.class).to eq(Array)
        expect(subject.count).to eq(3)
      end

      it 'should contain the commits' do
        expect(subject).to include('7652882 recent commit 1')
        expect(subject).to include('34e6f44 recent commit 2')
        expect(subject).to include('0b5a735 recent commit 3')
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to get the most recent commits' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get last 3 commits. STDERR was: stderr output')
      end
    end
  end

  describe '#checkout' do
    let(:git_branch) {'a-different-git-branch'}

    subject { described_class.checkout(git_branch) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'checks out the specified branch' do
        expect(described_class).to receive(:system).with('git checkout a-different-git-branch')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not checking out the branch' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not checkout branch: a-different-git-branch')
      end
    end
  end

  describe '#cherry_pick' do
    let(:git_cherrypick_commit) {'abc123'}

    subject { described_class.cherry_pick(git_cherrypick_commit) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'cherry_pick the specified commit' do
        expect(described_class).to receive(:system).with('git cherry-pick abc123')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not cherrypicking the commit' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not cherry_pick commit: abc123')
      end
    end
  end

  describe '#pull_current_branch' do

    subject { described_class.pull_current_branch }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'pulls the current branch' do
        expect(described_class).to receive(:system).with('git pull -r')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not checking out the branch' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not pull branch')
      end
    end
  end

  describe '#set_global_config' do
    let(:test_option) { 'test.option' }
    let(:test_value)  { 'value_to_set' }

    subject { described_class.set_global_config(test_option,test_value) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should set the global git config' do
        expect(described_class).to receive(:system).with('git config --global test.option "value_to_set"')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not setting global config' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not set global config test.option to value_to_set')
      end
    end
  end

  describe '#add_everything' do
    subject { described_class.add_everything }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should git add all' do
        expect(described_class).to receive(:system).with('git add -A')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not adding files' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not add files')
      end
    end
  end

  describe '#add_file' do
    let(:file_to_add) {'test_file.yml'}

    subject { described_class.add_file(file_to_add) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should git add the file' do
        expect(described_class).to receive(:system).with("git add #{file_to_add}")

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not adding the file ' do
        expect{ subject }.to raise_error(GitClient::GitError, "Could not add file: #{file_to_add}")
      end
    end
  end

  describe '#safe_commit' do
    let(:git_commit_message) { 'Beautiful commits for all' }

    subject { described_class.safe_commit(git_commit_message) }

    before { allow(described_class).to receive(:system).with('git diff --cached --exit-code').and_return(no_changes_staged) }

    context 'changes are staged' do
      let(:no_changes_staged) { false }

      context 'commit succeeds' do
        it 'makes a commit with the specified message' do
          expect(described_class).to receive(:system).with("git commit -m 'Beautiful commits for all'").and_return(true)

          subject
        end
      end

      context 'commit fails' do
        it 'throws an exception about committing' do
          expect(described_class).to receive(:system).with("git commit -m 'Beautiful commits for all'").and_return(false)
          expect{ subject }.to raise_error(GitClient::GitError, 'Commit failed')
        end
      end
    end

    context 'no changes are staged' do
      let(:no_changes_staged) { true }

      it 'advises that no changes were committed' do
        expect{ subject }.to output("No staged changes were available to commit, doing nothing.\n").to_stdout
      end
    end
  end

  describe '#git_tag_shas' do
    let(:dir)            { Dir.mktmpdir }
    let(:git_tag_output) { <<~OUTPUT
                             sha1   refs/tags/v1.0.0
                             sha2   refs/tags/v1.0.1
                             sha3   refs/tags/v1.1.0
                           OUTPUT
    }
    let(:stderr_output)  { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status) { double(:process_status) }

    subject { described_class.git_tag_shas(dir) }

    before { allow(Open3).to receive(:capture3).and_return([git_tag_output, stderr_output, process_status]) }

    context 'git works properly' do
      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the last git commit message' do
        expect(subject).to eq(['sha1', 'sha2', 'sha3'])
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to get the shas of the git tags' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not get git tag shas. STDERR was: stderr output')
      end
    end
  end

  describe '#get_file_contents_at_sha' do
    let(:dir)             { Dir.mktmpdir }
    let(:git_show_output) { <<~OUTPUT
                              CONTENT OF FILE
                            OUTPUT
    }
    let(:stderr_output)   { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)  { double(:process_status) }
    let(:sha)             { 'sha1' }
    let(:file)            { 'important_file.txt' }

    subject { described_class.get_file_contents_at_sha(dir, sha, file) }

    before { allow(Open3).to receive(:capture3).with('git show sha1:important_file.txt').and_return([git_show_output, stderr_output, process_status]) }

    context 'git works properly' do
      before { allow(process_status).to receive(:success?).and_return(true) }

      it 'should return the last git commit message' do
        expect(subject).to eq("CONTENT OF FILE\n")
      end
    end

    context 'git fails' do
      let(:stderr_output) { 'stderr output' }

      before { allow(process_status).to receive(:success?).and_return(false) }

      it 'throws an exception about being unable to show the file at specified sha' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not show important_file.txt at sha1. STDERR was: stderr output')
      end
    end
  end

  describe '#fetch' do
    let(:dir) {Dir.mktmpdir }
    subject { described_class.fetch(dir) }

    before { allow(described_class).to receive(:system).and_return(git_successful) }

    context 'git works properly' do
      let(:git_successful) { true }

      it 'should git fetch' do
        expect(described_class).to receive(:system).with('git fetch')

        subject
      end
    end

    context 'git fails' do
      let(:git_successful) { false }

      it 'throws an exception about not fetching' do
        expect{ subject }.to raise_error(GitClient::GitError, 'Could not fetch')
      end
    end
  end
end
