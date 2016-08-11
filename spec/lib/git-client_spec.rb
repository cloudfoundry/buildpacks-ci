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

      it 'throws an exception about being unable to read last commit message' do
        expect{ subject }.to raise_error('Could not get last commit message. STDERR was: stderr output')
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
        expect{ subject }.to raise_error('Could not add files')
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
          expect{ subject }.to raise_error('Commit failed')
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
end
