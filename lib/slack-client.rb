# encoding: utf-8
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class SlackClient
  def initialize(webhook, channel, username)
    @webhook = webhook
    @channel = channel
    @username = username
    raise 'invalid webhook for slack' unless validate_string @webhook
    raise 'invalid channel for slack' unless validate_string @channel
    raise 'invalid username for slack' unless validate_string @username
  end

  def post_to_slack(text)
    text = text.to_s
    raise 'requested slack post has no text' unless validate_string text

    payload = {
      text: text,
      channel: @channel,
      username: @username,
      icon_emoji: ':monkey_face:'
    }.to_json

    slack_uri = URI.parse(@webhook)

    request = Net::HTTP::Post.new(slack_uri)
    request.body = payload

    response = Net::HTTP.start(slack_uri.hostname, slack_uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise response.message if response.code != '200'

    response
  end

  private

  def validate_string(cred)
    !(cred.nil? || !cred.is_a?(String) || cred.empty?)
  end

  def validate_number(cred)
    !(cred.nil? || !cred.is_a?(Numeric))
  end
end
