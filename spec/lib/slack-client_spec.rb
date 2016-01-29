# encoding: utf-8
require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/slack-client'

describe SlackClient do
  let(:slack_webhook) { 'https://hooks.slack.com/services/hookmchook' }
  let(:channel) { '#mychannel' }
  let(:username) { 'a_fair_user' }

  describe '#initialize' do
    context 'the slack_webhook is nil' do
      subject { described_class.new(nil, channel, username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the channel is nil' do
      subject { described_class.new(slack_webhook, nil, username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the slack_webhook is empty' do
      subject { described_class.new('', channel, username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the channel is empty' do
      subject { described_class.new(slack_webhook, '', username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the slack_webhook is not a string' do
      subject { described_class.new(12_345, channel, username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the channel is not a string' do
      subject { described_class.new(slack_webhook, 12_345, username) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the username is nil' do
      subject { described_class.new(slack_webhook, channel, nil) }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'the username is empty' do
      subject { described_class.new(slack_webhook, channel, '') }

      it 'raises an exception without posting to Slack' do
        expect { subject }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#post_to_slack' do
    describe 'input checking' do
      let(:text) { 'OH NOOOOOOOOOOOOOOOOOO' }

      context 'the POST request is successful' do
        subject { described_class.new(slack_webhook, channel, username) }

        before do
          stub_request(:post, slack_webhook)
            .with(body: '{"text":"OH NOOOOOOOOOOOOOOOOOO","channel":"#mychannel","username":"a_fair_user","icon_emoji":":monkey_face:"}',
                  headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host' => 'hooks.slack.com', 'User-Agent' => 'Ruby' })
            .to_return(status: 200, body: 'ok', headers: {})
        end

        it 'receives the 200 status code' do
          response = subject.post_to_slack text
          expect(WebMock).to have_requested(:post, slack_webhook)
          expect(response.code).to eq '200'
        end

        it 'has the correct payload' do
          expected_payload = {
            text: text,
            channel: channel,
            username: username,
            icon_emoji: ':monkey_face:'
          }.to_json

          response = subject.post_to_slack text

          expect(WebMock).to have_requested(:post, slack_webhook)
            .with(body: expected_payload)
        end
      end

      context 'the post text is empty' do
        subject { described_class.new(slack_webhook, channel, username) }

        it 'raises an exception without posting to Slack' do
          expect { subject.post_to_slack '' }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, slack_webhook)
        end
      end

      context 'the post text is nil' do
        subject { described_class.new(slack_webhook, channel, username) }

        it 'raises an exception without posting to Slack' do
          expect { subject.post_to_slack nil }.to raise_error(RuntimeError)
          expect(WebMock).not_to have_requested(:post, slack_webhook)
        end
      end
    end

    describe 'API error checking' do
      before do
        stub_request(:post, slack_webhook)
          .with(headers: {
                  'Accept' => '*/*',
                  'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                  'Host' => 'hooks.slack.com',
                  'User-Agent' => 'Ruby'
                })
          .to_return(status: [500, 'server error'], body: 'i is error', headers: {})
      end

      context 'API call is not successful' do
        subject { described_class.new(slack_webhook, channel, username) }
        it 'raises an HTTP error' do
          expect { subject.post_to_slack 'YOU FOOL' }
            .to raise_error(RuntimeError)
        end
      end
    end
  end
end
