require 'net/http'
require 'digest'

class SourceInput
  attr_reader :url, :md5, :git_commit_sha, :type
  attr_accessor :name, :repo, :version, :sha256, :sha1

  def initialize(name, url, version, md5, sha256, sha1, git_commit_sha = nil, repo = '', type = '')
    @name = name
    @repo = repo
    @url = url
    @version = version
    @md5 = md5
    @sha256 = sha256
    @sha1 = sha1
    @git_commit_sha = git_commit_sha
    @type = type
  end

  def self.from_file(source_file)
    data = JSON.parse(File.open(source_file).read)
    if data['name']
      SourceInput.new(
        data['name'] || '',
        data['source_uri'] || '',
        data['version'] || '',
        nil,
        data['source_sha'] || '',
        nil
      )
    else
      SourceInput.new(
        data.dig('source', 'name') || '',
        data.dig('version', 'url') || '',
        data.dig('version', 'ref') || '',
        data.dig('version', 'md5_digest'),
        data.dig('version', 'sha256'),
        data.dig('version', 'sha1'),
        data.dig('version', 'git_commit_sha'),
        data.dig('source', 'repo') || '',
        data.dig('source', 'type') || ''
      )
    end
  end

  def sha_from_url
    response = Net::HTTP.get_response(URI(@url))
    Digest::SHA2.new(256).hexdigest(response.body)
  end

  def md5?
    !@md5.nil?
  end

  def sha256?
    !@sha256.nil?
  end

  def sha1?
    !@sha1.nil?
  end
end
