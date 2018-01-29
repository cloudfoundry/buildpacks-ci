# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/davos_client'

describe DavosClient do
  let(:token) { 'totes_a_real_api_key' }

  subject { described_class.new(token) }

  describe '#initialize' do
    context 'when the token is nil' do
      subject { described_class.new(nil) }

      it 'raises an exception' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#change' do
    it 'posts to davos API' do
      stub_request(:post, 'https://davos.cfapps.io/product_stories/1234').
        with(body: 'status=acknowledged', headers: {'Authorization'=>'Bearer totes_a_real_api_key'}).
        to_return(status: 303)

      subject.change('1234', status: 'acknowledged')
    end
  end
end
