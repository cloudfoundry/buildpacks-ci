# encoding: utf-8
require 'net/http'
require 'net/https'
require 'uri'

class DavosClient
  def initialize(token)
    @token = token
    raise 'Davos Token was not provided' if token.to_s.empty?
  end

  def change(story_id, params)
    return if story_id.to_s.empty?

    Net::HTTP.post(
      URI("https://davos.cfapps.io/product_stories/#{story_id}"),
      URI.encode_www_form(params),
      'Authorization' => "Bearer #{@token}"
    )
  end
end
