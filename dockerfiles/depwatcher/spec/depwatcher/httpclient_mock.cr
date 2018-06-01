require "../../src/depwatcher/base"

class HTTPClientMock < Depwatcher::HTTPClient
  @stubs = Hash(String, HTTP::Client::Response).new

  def get(url)
    @stubs[url] || raise "url(#{url}) was not stubbed"
  end

  def stub_get(url, res)
    @stubs[url] = res
  end
end
