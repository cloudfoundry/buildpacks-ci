# encoding: utf-8
require 'spec_helper.rb'
require 'digest'

describe 'finalize-buildpack task' do
  let(:changelog_path) { File.join(File.expand_path(File.dirname(__FILE__)), 'CHANGELOG') }

  context 'CHANGELOG has multiple version entries' do
    let(:new_version_changes) do
      <<~HEREDOC
         * Improve error messages for alternate root directory issues
           (https://www.pivotaltracker.com/story/show/106553928)

         * bin/detect script emits buildpack name and version
           (https://www.pivotaltracker.com/story/show/100757820)
      HEREDOC
    end
    let(:old_version_changes) do
      <<~HEREDOC
         * Log the location of downloaded resources
           (https://www.pivotaltracker.com/story/show/100853260)
      HEREDOC
    end
    let(:change_log) do
      <<~HEREDOC
         v1.6.24 Sep 08, 2016
         =====================

         #{new_version_changes}

         v1.6.23 Aug 31, 2016
         =====================

         #{old_version_changes}
      HEREDOC
    end

    before do
      File.write(changelog_path, change_log)
      execute('-c tasks/finalize-buildpack.yml -i buildpacks-ci=. -i buildpack=./spec/finalize-buildpack -i pivotal-buildpacks-cached=./spec/finalize-buildpack')
    end

    after { FileUtils.rm_rf(changelog_path) }

    it 'extracts only the latest version release notes from CHANGELOG into RECENT_CHANGES' do
      output = run("cat /tmp/build/*/buildpack-artifacts/RECENT_CHANGES && echo '\t'")
      expect(output).to include(new_version_changes)
      expect(output).to_not include(old_version_changes)
    end
  end

  context 'CHANGELOG only has a single version entry' do
    let(:new_version_changes) do
      <<~HEREDOC
         * Add CI pipeline
           (https://www.pivotaltracker.com/story/show/129962149)

         * Add CHANGELOG
           (https://www.pivotaltracker.com/story/show/129962149)
      HEREDOC
    end

    let(:change_log) do
      <<~HEREDOC
         v1.6.24 Sep 08, 2016
         =====================

         #{new_version_changes}
      HEREDOC
    end

    before do
      File.write(changelog_path, change_log)
      execute('-c tasks/finalize-buildpack.yml -i buildpacks-ci=. -i buildpack=./spec/finalize-buildpack -i pivotal-buildpacks-cached=./spec/finalize-buildpack')
    end

    after { FileUtils.rm_rf(changelog_path) }

    it 'extracts the latest version release notes from CHANGELOG into RECENT_CHANGES' do
      output = run("cat /tmp/build/*/buildpack-artifacts/RECENT_CHANGES && echo '\t'")
      expect(output).to include(new_version_changes)
    end
  end

  context 'default behavior' do

    before(:all) do
      change_log = <<~HEREDOC
                      v1.2.2 2015-10-24
                      ====================

                      * Improve error messages for alternate root directory issues
                        (https://www.pivotaltracker.com/story/show/106553928)

                      * bin/detect script emits buildpack name and version
                        (https://www.pivotaltracker.com/story/show/100757820)

                      * Log the location of downloaded resources
                        (https://www.pivotaltracker.com/story/show/100853260)


                      v1.2.1 Jul 16, 2015
                      ====================

                      * Adding helpful message for unsupported stack
                        (https://www.pivotaltracker.com/story/show/98579464)

                      * Compress nginx response body for more MIME types
                        (https://www.pivotaltracker.com/story/show/98128132)

                      * Update nginx to version 1.8.0
                        (https://www.pivotaltracker.com/story/show/97663450)

                      v1.2.0 Jun 24, 2015
                      ====================

                      * Remove nginx version display
                        (https://www.pivotaltracker.com/story/show/94542440)

                      * Remove lucid-specific binaries from manifest.yml
                        (https://www.pivotaltracker.com/story/show/96135874)

                      * Give helpful message on unsupported stacks
                        (https://www.pivotaltracker.com/story/show/96590146)
        HEREDOC
      @changelog_path = File.join(File.expand_path(File.dirname(__FILE__)), 'CHANGELOG')
      File.write(@changelog_path, change_log)
      execute('-c tasks/finalize-buildpack.yml -i buildpacks-ci=. -i buildpack=./spec/finalize-buildpack -i pivotal-buildpacks-cached=./spec/finalize-buildpack')
    end

    after(:all) { FileUtils.rm_rf(@changelog_path) }

    it 'emits shasum in CHANGELOG' do
      output = run("cat /tmp/build/*/buildpack-artifacts/RECENT_CHANGES && echo '\t'")
      changelog_sha = output.split("\n").last
      Dir.glob('specs/finalize-buildpack/*.zip') do |filename|
        actual_sha = '  * SHA256: ' + Digest::SHA256.file(filename).hexdigest
        expect(changelog_sha).to be == actual_sha
      end
    end

    it 'emits a valid markdown table of dependencies' do
      output = run("cat /tmp/build/*/buildpack-artifacts/RECENT_CHANGES && echo '\t'",20)
      expect(output).to include "Packaged binaries:"
      expect(output).to include "| name  | version | cf_stacks  |"
      expect(output).to include "|-------|---------|------------|"
      expect(output).to include "| nginx | 1.8.0   | cflinuxfs2 |"
    end

    it 'emits a valid markdown table of dependency default versions' do
      output = run("cat /tmp/build/*/buildpack-artifacts/RECENT_CHANGES && echo '\t'",20)
      expect(output).to include "Default binary versions:"
      expect(output).to include "| name  | version |"
      expect(output).to include "|-------|---------|"
      expect(output).to include "| nginx | 1.8.0   |"
    end

    it 'emits tag based on VERSION' do
      output = run("cat /tmp/build/*/buildpack-artifacts/tag && echo '\t'")
      version = File.read('./spec/finalize-buildpack/VERSION')
      expect(output).to include("v#{version}")
    end

    it 'emits a SHA256.txt file' do
      output = run("cat /tmp/build/*/buildpack-artifacts/*.SHA256SUM.txt && echo '\t'")
      expect(output).to include '6183bfc9d4c24cb123427b3b45d3b5ffa22d218adbe86cb48f204ce0a2c711fd  staticfile_buildpack-cached-v1.2.1.zip'
    end
  end
end
