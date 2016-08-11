# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/git-client'

describe GitClient do
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
end
