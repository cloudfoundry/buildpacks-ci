# encoding: utf-8
require 'spec_helper'
require 'yaml'
require_relative '../../../tasks/create-deprecation-stories/deprecation-notifier'

describe DeprecationNotifier do
  describe '#clone_repo' do
    let(:manifest) {"https://some-url"}

    context 'given a manifest and a date' do

      it 'returns entries in the manifest that will deprecate in less than 45 days from date' do
        date = Date.parse('2019-4-05')
        manifest_yaml = <<-eos
---
language: python
default_versions:
- name: python
  version: 2.7.x
dependency_deprecation_dates:
- version_line: 2.7.x
  name: python
  date: 2019-03-16
  link: https://docs.python.org/devguide/index.html#branchstatus
- version_line: 3.4.x
  name: python
  date: 2019-03-17
  link: https://docs.python.org/devguide/index.html#branchstatus
- version_line: 3.5.x
  name: python
  date: 2020-09-13
  link: https://docs.python.org/devguide/index.html#branchstatus
- version_line: 3.6.x
  name: python
  date: 2021-12-23
  link: https://docs.python.org/devguide/index.html#branchstatus
        eos

        manifest = YAML.load(manifest_yaml)

        result = find_dates(manifest, date)


        expect(result).to eq([
                                 {
                                     'version_line' => '2.7.x',
                                     'name' => 'python',
                                     'date' => '2019-03-16',
                                     'link' => 'https://docs.python.org/devguide/index.html#branchstatus'
                                 },
                                 {
                                     'version_line' => '3.4.x',
                                     'name' => 'python',
                                     'date' => '2019-03-17',
                                     'link' => 'https://docs.python.org/devguide/index.html#branchstatus'
                                 }
                             ])
      end
    end
  end
end
