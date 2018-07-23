# encoding: utf-8
require 'spec_helper'
require_relative '../../../tasks/update-buildpack-dependency/dependencies'

describe Dependencies do
  subject {
    described_class.new(
        dep,
        line,
        removal_strategy,
        dependencies,
        master_dependencies
    ).switch
  }
  let(:dependencies) do
    [['stack1'], ['stack2']].map do |stack|
      [
        { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => stack }
      ]
    end.flatten.sort_by { |d| [d['name'], d['version'], d['cf_stacks']] }.freeze
  end
  let(:master_dependencies) do
    [['stack1'], ['stack2']].map do |stack|
      [
        { 'name' => 'bundler', 'version' => '1.2.1', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '1.2.2', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '2.3.1', 'cf_stacks' => stack },
        { 'name' => 'ruby', 'version' => '2.3.2', 'cf_stacks' => stack }
      ]
    end.flatten.sort_by { |d| [d['name'], d['version'], d['cf_stacks']] }.freeze
  end


  context 'no version line specified' do
    let(:line) {nil}
    let(:removal_strategy) {'remove_all'}

    context 'new version is newer than all existing' do
      let(:dep) { { 'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack1'] } }

      it 'replaces all of the named dependencies' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack1'] }
        ])
      end
    end
    context 'new version is older than any existing' do
      let(:dep) { { 'name' => 'ruby', 'version' => '2.0.0', 'cf_stacks' => ['stack1'] }}
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end

  context 'version line is major' do
    let(:line) {"major"}
    let(:removal_strategy) {'remove_all'}

    context 'new version is newer than all existing on its line', :focus => true do
      let(:dep) {{'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1'] }}
      it 'replaces all of the named dependencies on its line' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack2'] },
          {'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1'] },
          {'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack2'] },
          {'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack2'] }
                              ])
      end
    end
    context 'new version is part of a new line' do
      let(:dep) {{'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack1'] }}
      it 'Maintains all old dependencies and adds the new one' do
        expect(subject).to eq(dependencies + [
            {'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack1']}
        ])
      end
    end
    context 'new version is older than any existing on its line' do
      let(:dep) {{'name' => 'ruby', 'version' => '2.3.5', 'cf_stacks' => ['stack1'] }}
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end

  context 'version line is minor' do
    let(:line) {"minor"}
    let(:removal_strategy) {'remove_all'}

    context 'new version is newer than all existing on its line' do
      let(:dep) {{'name' => 'ruby', 'version' => '1.2.5', 'cf_stacks' => ['stack1']}}
      it 'replaces all of the named dependencies on its line' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack2'] },
          {'name' => 'ruby', 'version' => '1.2.5', 'cf_stacks' => ['stack1']},
          {'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1']},
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack2'] },
          {'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack2'] },
          {'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack2'] }
                              ])
      end
    end
    context 'new version is part of a new line' do
      let(:dep) {{'name' => 'ruby', 'version' => '2.4.0', 'cf_stacks' => ['stack1']}}
      it 'Maintains all old dependencies and adds the new one' do
        expect(subject).to eq(dependencies + [
            {'name' => 'ruby', 'version' => '2.4.0', 'cf_stacks' => ['stack1']}
        ])
      end
    end
    context 'new version is older than any existing on its line' do
      let(:dep) {{'name' => 'ruby', 'version' => '2.3.5', 'cf_stacks' => ['stack1']}}
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end

  context 'removal_strategy is keep_master' do
    let(:line) {'major'}
    let(:removal_strategy) {'keep_master'}

    context 'new version is newer than all existing on its line' do
      let(:dep) {{'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1'] }}
      it 'replaces all of the named dependencies on its line keeping the latest from master' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack2'] }
        ])
      end
    end
  end

  context 'removal_strategy is keep_all' do
    let(:line) {'major'}
    let(:removal_strategy) {'keep_all'}
    context 'new version is newer than all existing on its line' do
      let(:dep) {{'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1'] }}
      it 'replaces all of the named dependencies on its line keeping the latest from master' do
        expect(subject).to eq([
                                  {'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1']},
                                  {'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2']},
                                  {'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2']},
                                  {'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack2']},
                                  {'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack2']},
                                  {'name' => 'ruby', 'version' => '1.4.0', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack2']},
                                  {'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1']},
                                  {'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack2']}
                              ])
      end
    end
  end

  # Ignore for now, until we decide how we want to handle dotnet's strange version lines
  xcontext 'when dotnet 2.1.201 already exists' do
    let(:dependencies) {[
        {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack1'] },
        {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack2'] },
        {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack1'] },
        {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack2'] },
        {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack1'] },
        {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack2'] },
    ].freeze}
    let(:master_dependencies) {[
        {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack1'] },
        {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack2'] },
        {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack1'] },
        {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack2'] },
    ]}

    let(:line) {nil}
    let(:removal_strategy) {'keep_master'}

    let(:dep) {{'name' => 'dotnet', 'version' => '2.1.302', 'cf_stacks' => ['stack1'] }}
    it 'keeps dotnet 2.1.201 when there is a new version of dotnet in the same line' do
      expect(subject).to eq([
                                {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack1'] },
                                {'name' => 'dotnet', 'version' => '2.1.201', 'cf_stacks' => ['stack2'] },
                                {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack1'] },
                                {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack2'] },
                                {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack2'] },
                                {'name' => 'dotnet', 'version' => '2.1.302', 'cf_stacks' => ['stack1'] }
                            ])
    end

    context 'when dotnet 2.1.201 gets rebuilt' do
      let(:dependencies) {[
          {'name' => 'dotnet', 'version' => '2.1.201', 'foo' => 'bar', 'cf_stacks' => ['stack1']},
          {'name' => 'dotnet', 'version' => '2.1.201', 'foo' => 'bar', 'cf_stacks' => ['stack2']},
          {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack1']},
          {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack2']},
          {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack1']},
          {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack2']}
      ].freeze}

      let(:dep) {{'name' => 'dotnet', 'version' => '2.1.201', 'foo' => 'baz', 'cf_stacks' => ['stack1'] }}
      it 'replaces dotnet 2.1.201 with dotnet 2.1.201' do
        expect(subject).to eq([
                                  {'name' => 'dotnet', 'version' => '2.1.201', 'foo' => 'baz', 'cf_stacks' => ['stack1']},
                                  {'name' => 'dotnet', 'version' => '2.1.201', 'foo' => 'bar', 'cf_stacks' => ['stack2']},
                                  {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack1']},
                                  {'name' => 'dotnet', 'version' => '2.1.300', 'cf_stacks' => ['stack2']},
                                  {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack1']},
                                  {'name' => 'dotnet', 'version' => '2.1.301', 'cf_stacks' => ['stack2']}
                              ])
      end
    end
  end

  context 'nginx' do
    let(:master_dependencies) {[
        {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
        {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
        {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack1']},
        {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2']},
    ]}
    let(:dependencies) {[
        {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
        {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
        {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack1']},
        {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2']},
    ].freeze}
    let(:line) { 'nginx' }
    let(:removal_strategy) { 'remove_all' }

    context 'updating the stable line first' do
      let(:dep) {{'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']}}

      it 'replaces the stable line and keeps the main line' do
        expect(subject).to eq([
                                  {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
                                  {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack1']},
                                  {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2']},
                                  {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']}
                              ])
      end
    end

    context 'updating the main line first' do
      let(:dep) {{'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']}}

      it 'replaces the main line and keeps the stable line' do
        expect(subject).to eq([
                                  {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
                                  {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
                                  {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2']},
                                  {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']}
                              ])
      end
    end

    context 'when the main line is already up-to-date' do
      let(:dependencies) {[
          {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
          {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack2']},
      ].freeze}
      let(:dep) {{'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']}}

      it 'replaces the stable line and keeps the up-to-date main line' do
        expect(subject).to eq([
                                  {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
                                  {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']},
                                  {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']},
                                  {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack2']}
                              ])
      end
    end

    context 'when the stable line is already up-to-date' do
      let(:dependencies) {[
          {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2']},
          {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack2']},
      ].freeze}
      let(:dep) {{'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']}}

      it 'replaces the main line and keeps the up-to-date stable line' do
        expect(subject).to eq([
                                { 'name' => 'nginx', 'version' => '1.13.1', 'cf_stacks' => ['stack2'] },
                                {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack1']},
                                {'name' => 'nginx', 'version' => '1.14.0', 'cf_stacks' => ['stack2']},
                                {'name' => 'nginx', 'version' => '1.15.0', 'cf_stacks' => ['stack1']}
                              ])
      end
    end

    context 'updating patch versions' do
      let(:dependencies) {[
          {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
          {'name' => 'nginx', 'version' => '1.13.2', 'cf_stacks' => ['stack1']},
          {'name' => 'nginx', 'version' => '1.13.2', 'cf_stacks' => ['stack2']},
      ].freeze}
      let(:dep) {{'name' => 'nginx', 'version' => '1.13.3', 'cf_stacks' => ['stack1']}}

      it 'replaces the patch version' do
        expect(subject).to eq([
                                {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack1']},
                                {'name' => 'nginx', 'version' => '1.12.0', 'cf_stacks' => ['stack2']},
                                {'name' => 'nginx', 'version' => '1.13.2', 'cf_stacks' => ['stack2']},
                                {'name' => 'nginx', 'version' => '1.13.3', 'cf_stacks' => ['stack1']}
                              ])
      end
    end
  end

  context 'adding a new stack' do
    let(:dependencies) do
        [
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] }
        ]
    end
    let(:master_dependencies) do
        [
          { 'name' => 'bundler', 'version' => '1.2.1', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.2', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.1', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.2', 'cf_stacks' => ['stack1'] }
        ]
    end

    let(:line) {nil}
    let(:removal_strategy) {'remove_all'}

    context 'new version with new stack' do
      let(:dep) { { 'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack2'] } }

      it 'does not affect any existing versions' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '3.0.0', 'cf_stacks' => ['stack2'] }
        ])
      end
    end

    context 'rebuilt version but with new stack' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] } }

      it 'does not affect any existing versions' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
        ])
      end
    end
    context 'rebuilt version, only one existing version, but with new stack' do
      let(:dep) { { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] } }

      it 'does not affect any existing versions' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack2'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
        ])
      end
    end

    context 'the new dep expands the number of stacks for an existing dep' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1', 'stack2'] } }
      let(:line) { 'major' }

      it 'replaces the existing dep with a dep with the extra stacks' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.2.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.3.4', 'cf_stacks' => ['stack1', 'stack2'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
        ])
      end
    end

    context 'the new dep is the latest version and contains new stacks' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.4.4', 'cf_stacks' => ['stack1', 'stack2'] } }
      let(:line) { 'major' }

      it 'adds the dep with a dep with the extra stacks and removes the old ones' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' => '1.2.3', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '1.4.4', 'cf_stacks' => ['stack1', 'stack2'] },
          { 'name' => 'ruby', 'version' => '2.3.4', 'cf_stacks' => ['stack1'] },
          { 'name' => 'ruby', 'version' => '2.3.6', 'cf_stacks' => ['stack1'] },
        ])
      end
    end
  end
end
