require 'spec_helper.rb'
require 'digest'

describe 'finalize-buildpack task' do
  before(:context) do
    puts "Test finalize-buildpack task..."
    @tasks = fly("execute -c tasks/finalize-buildpack.yml -i buildpacks-ci=. -i buildpack=./spec/finalize-buildpack -i pivotal-buildpacks-cached=./spec/finalize-buildpack")
    @id = @tasks.split("\n").first.split(' ').last
    puts "finalize-buildpack task id=#{@id}"
  end

  context '' do
    it 'should emit shasum in CHANGELOG' do
      output = fly("i -b #{@id} -n one-off bash -c 'cat /tmp/build/*/buildpack/RECENT_CHANGES'")
      changelog_sha = output.split("\n").last
      Dir.glob("specs/finalize-buildpack/*.zip") do |filename|
        actual_sha = "  * SHA256: " + Digest::SHA256.file(filename).hexdigest
        expect(changelog_sha).to be == actual_sha
      end
    end

    it 'should emit tag based on VERSION' do
      output = fly("i -b #{@id} -n one-off bash -c 'cat /tmp/build/*/tag'")
      version = File.read('./spec/finalize-buildpack/VERSION')
      expect(output).to be == "v#{version}"
    end
  end

end
