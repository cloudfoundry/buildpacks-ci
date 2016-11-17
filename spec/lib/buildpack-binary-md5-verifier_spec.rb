# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/buildpack-binary-md5-verifier'

describe BuildpackBinaryMD5Verifier do
  let(:buildpack_dir) { Dir.mktmpdir }

  describe '#run!' do
    let(:whitelist_file) { 'whitelist.yml' }
    let(:mapping) { double(:mapping) }

    before do
      whitelist = <<~WHITELIST
                  #this was vetted already
                  - https://download-binary.org
                  WHITELIST
      File.write(whitelist_file, whitelist)
    end

    after do
      File.delete(whitelist_file)
    end

    subject { described_class.run!(buildpack_dir, whitelist_file) }

    it "gets the uri to md5 mapping and shows mismatches of actual binaries" do
      expect(described_class).to receive(:get_uri_md5_sha_values).with(buildpack_dir, ['https://download-binary.org']).and_return(mapping)
      expect(described_class).to receive(:show_mismatches).with(mapping).and_return(true)
      expect(subject).to be_truthy
    end
  end

  describe '#get_uri_md5_sha_values' do
    let(:git_tag_shas)  { ['sha1', 'sha2']}
    let(:manifest1) { <<~TEST
                        dependencies:
                        - name: ruby
                          uri: uri_stub1
                          md5: md5_stub1
                      TEST
                    }
    let(:manifest2) { <<~TEST
                        dependencies:
                        - name: ruby
                          uri: uri_stub2
                          md5: md5_stub2
                      TEST
                    }
    let(:uris_to_ignore) { [] }

    before do
      allow(GitClient).to receive(:git_tag_shas).with(buildpack_dir).and_return(git_tag_shas)
      allow(GitClient).to receive(:get_file_contents_at_sha).with(buildpack_dir, 'sha1', 'manifest.yml').and_return(manifest1)
      allow(GitClient).to receive(:get_file_contents_at_sha).with(buildpack_dir, 'sha2', 'manifest.yml').and_return(manifest2)
    end

    subject { described_class.get_uri_md5_sha_values(buildpack_dir, uris_to_ignore) }

    it "gets a hash of buildpack binary uris with their expected md5s and the shas they came from" do
      expect(subject).to eq({
                             'uri_stub1' =>
                              {'md5' => 'md5_stub1',
                               'sha' => 'sha1'},
                             'uri_stub2' =>
                              {'md5' => 'md5_stub2',
                               'sha' => 'sha2'}
                            })
    end

    context 'repeat binary uris' do
      let(:manifest2) { manifest1 }

      it "gets a hash of buildpack binary uris without repeats" do
        expect(subject).to eq({
                               'uri_stub1' =>
                                {'md5' => 'md5_stub1',
                                 'sha' => 'sha1'}
                              })
      end
    end

    context 'dependencies missing md5s' do
      let(:manifest2) { <<~TEST
                          dependencies:
                          - name: ruby
                            uri: uri_stub2
                        TEST
                      }

      it "gets a hash of only buildpack binary uris that had md5s" do
        expect(subject).to eq({
                               'uri_stub1' =>
                                {'md5' => 'md5_stub1',
                                 'sha' => 'sha1'}
                              })
      end
    end

    context 'uris to ignore are present' do
      let(:uris_to_ignore) { ['uri_stub1'] }

      it "gets a hash of only buildpack binary uris that are not ignored" do
        expect(subject).to eq({
                               'uri_stub2' =>
                                {'md5' => 'md5_stub2',
                                 'sha' => 'sha2'}
                              })
      end
    end

    context 'no manifest at sha' do
      before do
        allow(GitClient).to receive(:git_tag_shas).with(buildpack_dir).and_return(git_tag_shas)
        allow(GitClient).to receive(:get_file_contents_at_sha).with(buildpack_dir, 'sha1', 'manifest.yml').and_return(manifest1)
        allow(GitClient).to receive(:get_file_contents_at_sha).with(buildpack_dir, 'sha2', 'manifest.yml').and_raise(GitClient::GitError.new("git file error message"))
      end

      it "outputs manifest errors but still gets a hash of buildpack binary uris that had md5s" do
        expect{ subject }.to_not output.to_stdout
        expect(subject).to eq({
                               'uri_stub1' =>
                                {'md5' => 'md5_stub1',
                                 'sha' => 'sha1'}
                              })
      end
    end

    context 'manifest at sha cannot be parsed' do
      let(:manifest1) { <<~TEST
                          dependencies:
                          - name: ruby
                          uri: uri_stub1
                            md5: md5_stub1
                        TEST
                      }

      it "outputs manifest errors but still gets a hash of buildpack binary uris that had md5s" do
        expect{ subject }.to output(/failed to parse manifest/).to_stdout
        expect(subject).to eq({
                               'uri_stub2' =>
                                {'md5' => 'md5_stub2',
                                 'sha' => 'sha2'}
                              })
      end
    end

    context 'manifest at sha is in an old, deprecated format' do
      let(:manifest1) { <<~TEST
                          dependencies:
                          - uri_stub1
                        TEST
                      }
      let(:manifest2) { <<~TEST
                          dependencies:
                          - uri_stub2
                        TEST
                      }

      it "outputs manifest errors but still gets a hash of buildpack binary uris that had md5s" do
        expect{ subject }.to output(/failed to parse manifest/).to_stdout
        expect(subject).to eq({})
      end
    end


  end

  describe '#show_mismatches' do
    let(:uri) { 'https://buildpacks.cloudfoundry.org/dependencies/bundler/bundler-1.12.5.tgz' }
    let(:uri_mapping) {{
      uri => {'md5' => 'md5_stub1', 'sha' => 'sha_stub1'}
    }}
    let(:gsubbed_file_name) { "https___buildpacks.cloudfoundry.org_dependencies_bundler_bundler_1.12.5.tgz" }
    let(:md5_stub)          { double(:md5_stub) }
    let(:actual_md5_stub)   { 'md5_stub1' }

    subject { described_class.show_mismatches(uri_mapping) }

    before do
      allow(described_class).to receive(:system)
      allow(Digest::MD5).to receive(:file).with(gsubbed_file_name).and_return(md5_stub)
      allow(md5_stub).to receive(:to_s).and_return(actual_md5_stub)
    end

    context 'md5s match' do
      it "should print a dot (.)" do
        expect{ subject }.to output(/working in .*\.$/m).to_stdout
        expect(subject).to be_truthy
      end

      context 'download and md5 check flakes' do
        before do
          allow(described_class).to receive(:system)
          allow(Digest::MD5).to receive(:file).with(gsubbed_file_name).and_return(md5_stub)
          allow(md5_stub).to receive(:to_s).and_return("flake", actual_md5_stub)
        end

        it "should retry and print a dot (.)" do
          expect(described_class).to receive(:system).exactly(2).times
          expect{ subject }.to output(/working in .*\.$/m).to_stdout
          expect(subject).to be_truthy
        end
      end
    end

    context 'md5s do not match' do
      let(:actual_md5_stub) { 'different_md5_stub' }

      it "should print an F" do
        expect{ subject }.to output(/working in .*\R$/m).to_stdout
        expect(subject).to be_falsey
      end

      it "should attempt to retry downloading and checking up to 3 times" do
        expect(described_class).to receive(:system).exactly(3).times
        expect(subject).to be_falsey
      end

      it "should print the actual vs desired md5s and the release sha" do
        expect{ subject }.to output(/#{uri}: actual different_md5_stub != desired md5_stub1, release sha: sha_stub1/).to_stdout
      end
    end
  end
end
