# encoding: utf-8
require 'spec_helper.rb'
require 'digest'
require 'tmpdir'
require_relative '../../../tasks/finalize-buildpack/buildpack-finalizer'

describe BuildpackFinalizer do
  let(:artifact_dir)         { Dir.mktmpdir }
  let(:buildpack_repo_dir)   { Dir.mktmpdir }
  let(:cached_buildpack_dir) { Dir.mktmpdir }
  let(:version)              { '1.2.2' }
  let(:changelog_path)       { File.join(buildpack_repo_dir, 'CHANGELOG') }
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
    File.write(File.join(cached_buildpack_dir, 'staticfile_buildpack-cached-v1.2.2+1231232.zip'), 'xxx')
    @sha256 = Digest::SHA256.file(File.join(cached_buildpack_dir, 'staticfile_buildpack-cached-v1.2.2+1231232.zip')).hexdigest
    File.write(changelog_path, change_log)
    allow(subject).to receive(:`)
    allow(subject).to receive(:system)
  end

  after do
    FileUtils.rm_rf(artifact_dir)
    FileUtils.rm_rf(buildpack_repo_dir)
    FileUtils.rm_rf(cached_buildpack_dir)
  end

  subject { described_class.new(artifact_dir, version, buildpack_repo_dir, cached_buildpack_dir) }

  describe '#write_changelog' do
    it 'extracts only the latest version release notes from CHANGELOG into RECENT_CHANGES' do
      subject.run
      output = File.read(File.join(artifact_dir, 'RECENT_CHANGES'))
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

    it 'extracts the latest version release notes from CHANGELOG into RECENT_CHANGES' do
      subject.run
      output = File.read(File.join(artifact_dir, 'RECENT_CHANGES'))
      expect(output).to include(new_version_changes)
      expect(output).to_not include(old_version_changes)
    end
  end

  context 'default behavior' do
    let(:change_log) do
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
    end

    let(:packaged_binaries) do
      <<~HEREDOC
         | name  | version | cf_stacks  |
         |-------|---------|------------|
         | nginx | 1.8.0   | cflinuxfs2 |
         HEREDOC
    end

    let(:default_versions) do
      <<~HEREDOC
         | name  | version | cf_stacks  |
         |-------|---------|------------|
         | nginx | 1.8.0   | cflinuxfs2 |
         HEREDOC
    end

    before do
      allow(subject).to receive(:`).with('BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --list').and_return(packaged_binaries)
      allow(subject).to receive(:`).with('BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --defaults').and_return(default_versions)
    end

    it 'emits shasum in RECENT_CHANGES' do
      subject.run
      output = File.read(File.join(artifact_dir, 'RECENT_CHANGES'))
      changelog_sha = output.split("\n").last

      expect(changelog_sha).to eq "  * SHA256: #{@sha256}"
    end

    it 'emits a valid markdown table of dependencies' do
      subject.run
      output = File.read(File.join(artifact_dir, 'RECENT_CHANGES'))

      expect(output).to include "Packaged binaries:"
      expect(output).to include "| name  | version | cf_stacks  |"
      expect(output).to include "|-------|---------|------------|"
      expect(output).to include "| nginx | 1.8.0   | cflinuxfs2 |"
    end

    it 'emits a valid markdown table of dependency default versions' do
      subject.run
      output = File.read(File.join(artifact_dir, 'RECENT_CHANGES'))

      expect(output).to include "Default binary versions:"
      expect(output).to include "| name  | version |"
      expect(output).to include "|-------|---------|"
      expect(output).to include "| nginx | 1.8.0   |"
    end

    it 'writes tag based on the VERSION' do
      subject.run
      output = File.read(File.join(artifact_dir, 'tag'))

      expect(output).to eq("v#{version}")
    end

    it 'emits a SHA256.txt file' do
      subject.run
      output = File.read(File.join(artifact_dir, 'staticfile_buildpack-cached-v1.2.2.zip.SHA256SUM.txt'))
      expect(output).to eq "#{@sha256}  staticfile_buildpack-cached-v1.2.2.zip"
    end

    it 'moves the cached buildpack to the artifacts dir' do
      subject.run
      expect(File.exist? File.join(artifact_dir, 'staticfile_buildpack-cached-v1.2.2.zip')).to be_truthy
    end
  end
end
