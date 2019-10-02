require "../../src/depwatcher/base"

class HTTPClientMock < Depwatcher::HTTPClient
  @stubs = Hash(Tuple(String, HTTP::Headers?), HTTP::Client::Response).new

  def get(url, headers : HTTP::Headers? = nil) : HTTP::Client::Response
    @stubs[{url, headers}] || raise "url (#{url}) with headers (#{headers}) was not stubbed"
  end

  def stub_get(url, headers, res)
    @stubs[{url, headers}] = res
  end
end
