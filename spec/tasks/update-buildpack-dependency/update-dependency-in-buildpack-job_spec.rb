# encoding: utf-8
require 'spec_helper'
require_relative '../../../tasks/update-buildpack-dependency/dependencies'

describe Dependencies do
  subject { described_class.new(dep, line, keep_master, dependencies, master_dependencies).switch }
  let(:dependencies) { [
    { 'name' => 'bundler', 'version' =>  '1.2.3' },
    { 'name' => 'ruby', 'version' =>  '1.2.3' },
    { 'name' => 'ruby', 'version' =>  '1.2.4' },
    { 'name' => 'ruby', 'version' =>  '1.3.4' },
    { 'name' => 'ruby', 'version' =>  '2.3.4' },
    { 'name' => 'ruby', 'version' =>  '2.3.6' }
  ].freeze }
  let(:master_dependencies) { [
    { 'name' => 'bundler', 'version' =>  '1.2.1' },
    { 'name' => 'ruby', 'version' =>  '1.2.2' },
    { 'name' => 'ruby', 'version' =>  '1.2.3' },
    { 'name' => 'ruby', 'version' =>  '2.3.1' },
    { 'name' => 'ruby', 'version' =>  '2.3.2' }
  ] }

  context 'no version line specified' do
    let(:line) { nil }
    let(:keep_master) { nil }

    context 'new version is newer than all existing' do
      let(:dep) { { 'name' => 'ruby', 'version' => '3.0.0' } }
      it 'replaces all of the named dependencies' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' =>  '1.2.3' },
          { 'name' => 'ruby', 'version' =>  '3.0.0' }
        ])
      end
    end
    context 'new version is older than any existing' do
      let(:dep) { { 'name' => 'ruby', 'version' => '2.0.0' } }
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end

  context 'version line is major' do
    let(:line) { "major" }
    let(:keep_master) { nil }

    context 'new version is newer than all existing on its line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.4.0' } }
      it 'replaces all of the named dependencies on its line' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' =>  '1.2.3' },
          { 'name' => 'ruby', 'version' =>  '1.4.0' },
          { 'name' => 'ruby', 'version' =>  '2.3.4' },
          { 'name' => 'ruby', 'version' =>  '2.3.6' }
        ])
      end
    end
    context 'new version is part of a new line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '3.0.0' } }
      it 'Maintains all old dependencies and adds the new one' do
        expect(subject).to eq(dependencies + [
          { 'name' => 'ruby', 'version' =>  '3.0.0' }
        ])
      end
    end
    context 'new version is older than any existing on its line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '2.3.5' } }
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end
  context 'version line is minor' do
    let(:line) { "minor" }
    let(:keep_master) { nil }

    context 'new version is newer than all existing on its line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.2.5' } }
      it 'replaces all of the named dependencies on its line' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' =>  '1.2.3' },
          { 'name' => 'ruby', 'version' =>  '1.2.5' },
          { 'name' => 'ruby', 'version' =>  '1.3.4' },
          { 'name' => 'ruby', 'version' =>  '2.3.4' },
          { 'name' => 'ruby', 'version' =>  '2.3.6' }
        ])
      end
    end
    context 'new version is part of a new line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '2.4.0' } }
      it 'Maintains all old dependencies and adds the new one' do
        expect(subject).to eq(dependencies + [
          { 'name' => 'ruby', 'version' =>  '2.4.0' }
        ])
      end
    end
    context 'new version is older than any existing on its line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '2.3.5' } }
      it 'returns unchanged dependencies' do
        expect(subject).to eq(dependencies)
      end
    end
  end

  context 'keep_master is true'  do
    let(:line) { 'major' }
    let(:keep_master) { 'true' }
    context 'new version is newer than all existing on its line' do
      let(:dep) { { 'name' => 'ruby', 'version' => '1.4.0' } }
      it 'replaces all of the named dependencies on its line keeping the latest from master' do
        expect(subject).to eq([
          { 'name' => 'bundler', 'version' =>  '1.2.3' },
          { 'name' => 'ruby', 'version' =>  '1.2.3' },
          { 'name' => 'ruby', 'version' =>  '1.4.0' },
          { 'name' => 'ruby', 'version' =>  '2.3.4' },
          { 'name' => 'ruby', 'version' =>  '2.3.6' }
        ])
      end
    end
  end
end
