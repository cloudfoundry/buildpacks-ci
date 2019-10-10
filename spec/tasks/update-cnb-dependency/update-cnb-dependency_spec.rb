# encoding: utf-8
require 'spec_helper'
require_relative '../../../tasks/update-cnb-dependency/cnb_dependencies'

describe CNBDependencies do
  subject {
    described_class.new(
        dep,
        line,
        removal_strategy,
        dependencies,
        dependencies_latest_released
    )
  }

  context 'updating default_versions' do
    context "removal_strategy isn't remove_all" do
      let(:removal_strategy) {'remove_none'}

    end

    context "removal_strategy is remove_all" do
      let(:removal_strategy) {'remove_all'}

    end

  end

  context 'switching dependencies' do
    let(:dependencies) do
      [['stack1'], ['stack2']].map do |stack|
        [
          { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => stack }
        ]
      end.flatten.sort_by { |d| [d['id'], d['version'], d['stacks']] }.freeze
    end
    let(:dependencies_latest_released) do
      [['stack1'], ['stack2']].map do |stack|
        [
          { 'id' => 'bundler', 'version' => '1.2.1', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '1.2.2', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '2.3.1', 'stacks' => stack },
          { 'id' => 'ruby', 'version' => '2.3.2', 'stacks' => stack }
        ]
      end.flatten.sort_by { |d| [d['id'], d['version'], d['stacks']] }.freeze
    end

    context 'no version line specified' do
      let(:line) {nil}
      let(:removal_strategy) {'remove_all'}

      context 'new version is newer than all existing' do
        let(:dep) { { 'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack1'] } }

        it 'replaces all of the idd dependencies' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack1'] }
          ])
        end
      end
      context 'new version is older than any existing' do
        let(:dep) { { 'id' => 'ruby', 'version' => '2.0.0', 'stacks' => ['stack1'] }}
        it 'returns unchanged dependencies' do
          expect(subject.switch).to eq(dependencies)
        end
      end
    end

    context 'version line is major' do
      let(:line) {"major"}
      let(:removal_strategy) {'remove_all'}

      context 'new version is newer than all existing on its line', :focus => true do
        let(:dep) {{'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1'] }}
        it 'replaces all of the idd dependencies on its line' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack2'] },
            {'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1'] },
            {'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack2'] },
            {'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack2'] }
                                ])
        end
      end
      context 'new version is part of a new line' do
        let(:dep) {{'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack1'] }}
        it 'Maintains all old dependencies and adds the new one' do
          expect(subject.switch).to eq(dependencies + [
              {'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack1']}
          ])
        end
      end
      context 'new version is older than any existing on its line' do
        let(:dep) {{'id' => 'ruby', 'version' => '2.3.5', 'stacks' => ['stack1'] }}
        it 'returns unchanged dependencies' do
          expect(subject.switch).to eq(dependencies)
        end
      end
    end

    context 'version line is minor' do
      let(:line) {"minor"}
      let(:removal_strategy) {'remove_all'}

      context 'new version is newer than all existing on its line' do
        let(:dep) {{'id' => 'ruby', 'version' => '1.2.5', 'stacks' => ['stack1']}}
        it 'replaces all of the idd dependencies on its line' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack2'] },
            {'id' => 'ruby', 'version' => '1.2.5', 'stacks' => ['stack1']},
            {'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1']},
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack2'] },
            {'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack2'] },
            {'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack2'] }
                                ])
        end
      end
      context 'new version is part of a new line' do
        let(:dep) {{'id' => 'ruby', 'version' => '2.4.0', 'stacks' => ['stack1']}}
        it 'Maintains all old dependencies and adds the new one' do
          expect(subject.switch).to eq(dependencies + [
              {'id' => 'ruby', 'version' => '2.4.0', 'stacks' => ['stack1']}
          ])
        end
      end
      context 'new version is older than any existing on its line' do
        let(:dep) {{'id' => 'ruby', 'version' => '2.3.5', 'stacks' => ['stack1']}}
        it 'returns unchanged dependencies' do
          expect(subject.switch).to eq(dependencies)
        end
      end
    end

    context 'removal_strategy is keep_latest_released' do
      let(:line) {'major'}
      let(:removal_strategy) {'keep_latest_released'}

      context 'new version is newer than all existing on its line' do
        let(:dep) {{'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1'] }}
        it 'replaces all of the idd dependencies on its line keeping the latest from last released buildpack' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack2'] }
          ])
        end
      end
    end

    context 'removal_strategy is keep_all' do
      let(:line) {'major'}
      let(:removal_strategy) {'keep_all'}
      context 'new version is newer than all existing on its line' do
        let(:dep) {{'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1'] }}
        it 'replaces all of the idd dependencies on its line keeping the latest from last released buildpack' do
          expect(subject.switch).to eq([
                                    {'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1']},
                                    {'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2']},
                                    {'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2']},
                                    {'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack2']},
                                    {'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack2']},
                                    {'id' => 'ruby', 'version' => '1.4.0', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack2']},
                                    {'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1']},
                                    {'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack2']}
                                ])
        end
      end
    end

    context 'nginx' do
      let(:dependencies_latest_released) {[
          {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
          {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
          {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack1']},
          {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2']},
      ]}
      let(:dependencies) {[
          {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
          {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
          {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack1']},
          {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2']},
      ].freeze}
      let(:line) { 'nginx' }
      let(:removal_strategy) { 'remove_all' }

      context 'updating the stable line first' do
        let(:dep) {{'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']}}

        it 'replaces the stable line and keeps the main line' do
          expect(subject.switch).to eq([
                                    {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
                                    {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack1']},
                                    {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2']},
                                    {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']}
                                ])
        end
      end

      context 'updating the main line first' do
        let(:dep) {{'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']}}

        it 'replaces the main line and keeps the stable line' do
          expect(subject.switch).to eq([
                                    {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
                                    {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
                                    {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2']},
                                    {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']}
                                ])
        end
      end

      context 'when the main line is already up-to-date' do
        let(:dependencies) {[
            {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
            {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack2']},
        ].freeze}
        let(:dep) {{'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']}}

        it 'replaces the stable line and keeps the up-to-date main line' do
          expect(subject.switch).to eq([
                                    {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
                                    {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']},
                                    {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']},
                                    {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack2']}
                                ])
        end
      end

      context 'when the stable line is already up-to-date' do
        let(:dependencies) {[
            {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2']},
            {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack2']},
        ].freeze}
        let(:dep) {{'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']}}

        it 'replaces the main line and keeps the up-to-date stable line' do
          expect(subject.switch).to eq([
                                  { 'id' => 'nginx', 'version' => '1.13.1', 'stacks' => ['stack2'] },
                                  {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack1']},
                                  {'id' => 'nginx', 'version' => '1.14.0', 'stacks' => ['stack2']},
                                  {'id' => 'nginx', 'version' => '1.15.0', 'stacks' => ['stack1']}
                                ])
        end
      end

      context 'updating patch versions' do
        let(:dependencies) {[
            {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
            {'id' => 'nginx', 'version' => '1.13.2', 'stacks' => ['stack1']},
            {'id' => 'nginx', 'version' => '1.13.2', 'stacks' => ['stack2']},
        ].freeze}
        let(:dep) {{'id' => 'nginx', 'version' => '1.13.3', 'stacks' => ['stack1']}}

        it 'replaces the patch version' do
          expect(subject.switch).to eq([
                                  {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack1']},
                                  {'id' => 'nginx', 'version' => '1.12.0', 'stacks' => ['stack2']},
                                  {'id' => 'nginx', 'version' => '1.13.2', 'stacks' => ['stack2']},
                                  {'id' => 'nginx', 'version' => '1.13.3', 'stacks' => ['stack1']}
                                ])
        end
      end
    end

    context 'adding a new stack' do
      let(:dependencies) do
          [
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] }
          ]
      end
      let(:dependencies_latest_released) do
          [
            { 'id' => 'bundler', 'version' => '1.2.1', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.2', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.1', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.2', 'stacks' => ['stack1'] }
          ]
      end

      let(:line) {nil}
      let(:removal_strategy) {'remove_all'}

      context 'new version with new stack' do
        let(:dep) { { 'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack2'] } }

        it 'does not affect any existing versions' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '3.0.0', 'stacks' => ['stack2'] }
          ])
        end
      end

      context 'rebuilt version but with new stack' do
        let(:dep) { { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] } }

        it 'does not affect any existing versions' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
          ])
        end
      end
      context 'rebuilt version, only one existing version, but with new stack' do
        let(:dep) { { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] } }

        it 'does not affect any existing versions' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack2'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
          ])
        end
      end

      context 'the new dep expands the number of stacks for an existing dep' do
        let(:dep) { { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1', 'stack2'] } }
        let(:line) { 'major' }

        it 'replaces the existing dep with a dep with the extra stacks' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.2.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.3.4', 'stacks' => ['stack1', 'stack2'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
          ])
        end
      end

      context 'the new dep is the latest version and contains new stacks' do
        let(:dep) { { 'id' => 'ruby', 'version' => '1.4.4', 'stacks' => ['stack1', 'stack2'] } }
        let(:line) { 'major' }

        it 'adds the dep with a dep with the extra stacks and removes the old ones' do
          expect(subject.switch).to eq([
            { 'id' => 'bundler', 'version' => '1.2.3', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '1.4.4', 'stacks' => ['stack1', 'stack2'] },
            { 'id' => 'ruby', 'version' => '2.3.4', 'stacks' => ['stack1'] },
            { 'id' => 'ruby', 'version' => '2.3.6', 'stacks' => ['stack1'] },
          ])
        end
      end
    end
  end
end
