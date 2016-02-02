# encoding: utf-8
require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/new-releases-detector'

describe NewReleasesDetector do
  before { allow(subject).to receive(:warn) {} }

  def to_tags(names)
    names.collect{|n| OpenStruct.new(name: n) }
  end
  let(:new_releases_dir) { Dir.mktmpdir }

  subject { described_class.new(new_releases_dir) }

  describe '#initialize' do
    it 'sets new_releases_dir' do
      expect(subject.new_releases_dir).to eq(new_releases_dir)
    end

  end

  context '#perform!' do
    let(:github_username) { "github_username" }
    let(:github_password) { "github_password1!" }

    before do
      allow(Octokit).to receive(:tags).and_return([])
      allow(subject).to receive(:open).with(/python/).and_return(double(read: {'tags' => []}.to_json))
      allow(subject).to receive(:open).with(/openjdk/).and_return(double(read: {}.to_yaml))

      allow(ENV).to receive(:fetch).with('GITHUB_USERNAME').and_return(github_username)
      allow(ENV).to receive(:fetch).with('GITHUB_PASSWORD').and_return(github_password)
    end

    context 'configures Octokit' do

      before do
      end

      it 'should set the autopaginate to true' do
        expect(Octokit).to receive(:auto_paginate=).with(true).at_least(:once)
        subject.perform!
      end
    end

    context 'for cf-release' do
      it 'outputs new releases' do
        expect(Octokit).to receive(:tags)
          .with('cloudfoundry/cf-release')
          .and_return(to_tags %w{v1 v2})

        expect {
          subject.perform!
        }.to output("There are *2* new updates to the *cfrelease* dependency:\n" \
                    "- version *v1*\n" \
                    "- version *v2*\n"
                   ).to_stdout
      end

      context 'when there are no new releases' do
        before { allow(subject).to receive(:warn).and_call_original }

        it 'outputs there are no new updates' do
          expect(Octokit).to receive(:tags)
            .with('cloudfoundry/cf-release')
            .and_return(to_tags %w{v1 v2})

          subject.perform!

          expect {
            subject.perform!
          }.to output(/There are no new updates to the \*cfrelease\* dependency\n/).to_stderr
        end
      end
    end

    context 'for python' do
      it 'outputs new releases' do
        expect(subject).to receive(:open)
          .with('https://hg.python.org/cpython/json-tags')
          .and_return(double(read: {tags: [{tag: 'a'}, {tag: 'b'}]}.to_json))

        expect {
          subject.perform!
        }.to output("There are *2* new updates to the *python* dependency:\n" \
                    "- version *a*\n" \
                    "- version *b*\n"
                   ).to_stdout
      end

      context 'when there are no new releases' do
        before { allow(subject).to receive(:warn).and_call_original }

        it 'outputs there are no new updates' do
          expect(subject).to receive(:open)
            .with('https://hg.python.org/cpython/json-tags')
            .and_return(double(read: {tags: [{tag: 'a'}, {tag: 'b'}]}.to_json))

          subject.perform!

          expect {
            subject.perform!
          }.to output(/There are no new updates to the \*python\* dependency\n/).to_stderr
        end
      end
    end

    context 'for openjdk' do
      it 'outputs new releases' do
        expect(subject).to receive(:open)
          .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
          .and_return(double(read: {v1: 1, v2: 2}.to_yaml))

        expect {
          subject.perform!
        }.to output("There are *2* new updates to the *openjdk* dependency:\n" \
                    "- version *v1*\n" \
                    "- version *v2*\n"
                   ).to_stdout
      end

      it 'writes to a file the latest releases' do
        expect(subject).to receive(:open)
          .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
          .and_return(double(read: {v1: 1, v2: 2}.to_yaml))

        subject.perform!
        expect(YAML.load_file("#{new_releases_dir}/openjdk.yaml")).to eq [:v1, :v2]
      end

      context 'when there are new releases' do
        it 'only displays the latest release to STDOUT' do
          expect(subject).to receive(:open)
            .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
            .and_return(double(read: {v1: 1, v2: 2}.to_yaml))

          subject.perform!
          expect(subject).to receive(:open)
            .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
            .and_return(double(read: {v1: 1, v2: 2, v3: 3}.to_yaml))

          expect {
            subject.perform!
          }.to output("There are *1* new updates to the *openjdk* dependency:\n" \
                      "- version *v3*\n"
                     ).to_stdout
        end
      end

      context 'when there are no new releases' do
        before { allow(subject).to receive(:warn).and_call_original }

        it 'outputs there are no new updates' do
          expect(subject).to receive(:open)
            .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
            .and_return(double(read: {v1: 1, v2: 2}.to_yaml))

          subject.perform!

          expect {
            subject.perform!
          }.to output(/There are no new updates to the \*openjdk\* dependency\n/).to_stderr
        end

        it 'does not changes the contents of the file' do
          expect(subject).to receive(:open)
            .with('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml')
            .and_return(double(read: {v1: 1, v2: 2}.to_yaml))

          subject.perform!

          expect {
            subject.perform!
          }.to_not change { File.read("#{new_releases_dir}/openjdk.yaml") }
        end
      end
    end
  end
end
