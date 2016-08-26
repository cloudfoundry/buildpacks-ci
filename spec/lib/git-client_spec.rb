# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/git-client'

describe GitClient do
  describe '#last_commit_message' do
    let(:dir)                 { Dir.mktmpdir }
    let(:last_commit_message) { 'this should not matter but is here to avoid undefined symbols' }
    let(:stderr_output)       { 'this should not matter but is here to avoid undefined symbols' }
    let(:process_status)      { double(:process_status) }

    subject { described_class.last_commit_message(dir) }

    before { allow(Open3).to receive(:capture3).and_return([last_commit_message, stderr_output, process_status]) }

    context 'git works properly' do
      let(:last_commit_message) { 'I was last committed' }

      before { allow(process_status).to receive(:success?).and_return(true) }

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

end
