# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/usn-release-notes'

# These tests should just be used to verify that we are correctly scraping a CVE,
# should be useful if getting release notes break again. 

describe UsnReleaseNotes do
  let(:usn_id) {'3806-1'}
  WebMock.allow_net_connect!

  after(:all){
    WebMock.disable_net_connect!
  }

  subject { described_class.new(usn_id) }

  describe '#initialize' do
    context 'using an invalid usn_id' do
      subject { described_class.new('garbage') }

      it 'raises an exception' do
        expect { subject.doc.to raise_error(OpenURI::HTTPError) }
      end
    end

    context 'using a valid usn_id' do
      subject { described_class.new(usn_id) }

      it 'raises an exception without posting to Tracker' do
        expect(subject.usn_title).not_to be_empty
      end
    end
  end
  describe '#release_note_text' do
    context 'should get release note for valid usn_id' do
      subject {described_class.new(usn_id) }
      it 'returns the release note' do
        expect(subject.text).not_to include 'Nothing found in description'
        expect(subject.text).not_to include 'Unable to get description'
        expect(subject.text).not_to be_empty
      end
    end
  end
end
