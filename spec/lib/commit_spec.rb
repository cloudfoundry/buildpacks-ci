# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/commit'

describe Commit do
  describe '#to_s' do
    it 'only subject' do
      obj = described_class.new({"subject"=>"Hi Mom"})
      expect(obj.to_s).to eq "* Hi Mom"
    end

    it 'body is indented' do
      obj = described_class.new({"subject"=>"Hi Mom", "body"=>"Rock climbing\nrocks"})
      expect(obj.to_s).to eq "* Hi Mom\n  Rock climbing\n  rocks"
    end

    it 'extracts story from subject' do
      obj = described_class.new({"subject"=>"Hi Dad [#6789]"})
      expect(obj.to_s).to eq "* Hi Dad\n  (https://www.pivotaltracker.com/story/show/6789)"
    end

    it 'extracts story from body' do
      obj = described_class.new({"subject"=>"Hi Dad", "body"=>"Parachuting is awesome\n[#4321]"})
      expect(obj.to_s).to eq "* Hi Dad\n  Parachuting is awesome\n  (https://www.pivotaltracker.com/story/show/4321)"
    end
  end

  describe '.recent' do
    it 'runs git log with json outputting arguments' do
      allow(Open3).to receive(:capture2).and_return('', nil)
      expect(Open3).to receive(:capture2).with(%q{git log --pretty=format:'{"commit": "%H", "subject": "%s", "body": "%b"},' v1.3.4..HEAD})

      described_class.recent('1.3.4')
    end

    context 'parsable output' do
      before { allow(Open3).to receive(:capture2).and_return('{"subject":"Hi"},{"subject":"Bye"},', nil) }

      it 'returns an array of commits' do
        commits = described_class.recent('1.2.3')
        expect(commits.map(&:subject)).to eq ["Hi", "Bye"]
      end
    end

    context 'parse exceptions' do
      before { allow(Open3).to receive(:capture2).and_return('{"subject":"Quote " inside text"},{"subject":"Bye"},', nil) }

      it 'are bubbled up' do
        expect { described_class.recent('1.2.3') }.to raise_error JSON::ParserError
      end
    end
  end
end
