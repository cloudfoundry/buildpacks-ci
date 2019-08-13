require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../../lib/release-notes-creator'
require_relative '../../lib/usn-release-notes'

describe RootfsReleaseNotesCreator do

  let(:temp_dir)         { Dir.mktmpdir }
  let(:cves_yaml_file)   { File.join(temp_dir, 'ubuntu14.04.yml' )}
  let(:old_receipt_file) { File.join(temp_dir, 'old.txt' )}
  let(:new_receipt_file) { File.join(temp_dir, 'new.txt' )}

  let(:cves_yaml) do <<~YAML
    ---
    - title: 'USN-3123-1: curl vulnerabilities'
      stack_release: unreleased
    - title: 'USN-3119-1: Bind vulnerability'
      stack_release: unreleased
    - title: 'USN-3117-1: GD library vulnerabilities'
      stack_release: 1.90.0
    - title: 'USN-3116-1: DBus vulnerabilities'
      stack_release: 1.90.0
      YAML
  end

  let(:new_receipt) do <<~RECEIPT
Rootfs SHASUM: 6620831b4e8e096257e75df01b1f28a62504e6de

Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                               Version                             Architecture Description
+++-==================================-===================================-============-===============================================================================
ii  libcurl3:amd64                     7.35.0-1ubuntu2.10                  amd64        easy-to-use client-side URL transfer library (OpenSSL flavour)
ii  libcurl3-gnutls:amd64              7.35.0-1ubuntu2.10                  amd64        easy-to-use client-side URL transfer library (GnuTLS flavour)
ii  libcurl4-openssl-dev:amd64         7.35.0-1ubuntu2.10                  amd64        development files and documentation for libcurl (OpenSSL flavour)
ii  libcwidget3                        0.5.16-3.5ubuntu1                   amd64        high-level terminal interface library for C++ (runtime files)
ii  libdatrie1:amd64                   0.2.8-1                             amd64        Double-array trie library
ii  libdb5.3:amd64                     5.3.28-3ubuntu3                     amd64        Berkeley v5.3 Database Libraries [runtime]
ii  libdbus-1-3:amd64                  1.6.18-0ubuntu4.4                   amd64        simple interprocess messaging system (library)
  RECEIPT
  end

  let(:old_receipt) do <<~RECEIPT
Rootfs SHASUM: ffffffffffffffffffffffffffff

Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                               Version                             Architecture Description
+++-==================================-===================================-============-===============================================================================
ii  libcurl3:amd64                     7.35.0-1ubuntu2.9                   amd64        easy-to-use client-side URL transfer library (OpenSSL flavour)
ii  libcurl3-gnutls:amd64              7.35.0-1ubuntu2.9                   amd64        easy-to-use client-side URL transfer library (GnuTLS flavour)
ii  libcurl4-openssl-dev:amd64         7.35.0-1ubuntu2.9                   amd64        development files and documentation for libcurl (OpenSSL flavour)
ii  libcwidget3                        0.5.16-3.5ubuntu1                   amd64        high-level terminal interface library for C++ (runtime files)
ii  libdatrie1:amd64                   0.2.8-1                             amd64        Double-array trie library
ii  libdb5.3:amd64                     5.3.28-3ubuntu3                     amd64        Berkeley v5.3 Database Libraries [runtime]
ii  libdbus-1-3:amd64                  1.6.18-0ubuntu4.3                   amd64        simple interprocess messaging system (library)
  RECEIPT
  end

  let(:diff_section) do <<~DIFF
-ii  libcurl3:amd64             7.35.0-1ubuntu2.9  amd64  easy-to-use client-side URL transfer library (OpenSSL flavour)
-ii  libcurl3-gnutls:amd64      7.35.0-1ubuntu2.9  amd64  easy-to-use client-side URL transfer library (GnuTLS flavour)
-ii  libcurl4-openssl-dev:amd64 7.35.0-1ubuntu2.9  amd64  development files and documentation for libcurl (OpenSSL flavour)
+ii  libcurl3:amd64             7.35.0-1ubuntu2.10 amd64  easy-to-use client-side URL transfer library (OpenSSL flavour)
+ii  libcurl3-gnutls:amd64      7.35.0-1ubuntu2.10 amd64  easy-to-use client-side URL transfer library (GnuTLS flavour)
+ii  libcurl4-openssl-dev:amd64 7.35.0-1ubuntu2.10 amd64  development files and documentation for libcurl (OpenSSL flavour)
-ii  libdbus-1-3:amd64          1.6.18-0ubuntu4.3  amd64  simple interprocess messaging system (library)
+ii  libdbus-1-3:amd64          1.6.18-0ubuntu4.4  amd64  simple interprocess messaging system (library)
  DIFF
  end

  let(:release_notes_output) do <<~DIFF
Notably, this release addresses:

USN-3123-1 with cve information

USN-3119-1 with cve information


```
-ii  libcurl3:amd64             7.35.0-1ubuntu2.9  amd64  easy-to-use client-side URL transfer library (OpenSSL flavour)
-ii  libcurl3-gnutls:amd64      7.35.0-1ubuntu2.9  amd64  easy-to-use client-side URL transfer library (GnuTLS flavour)
-ii  libcurl4-openssl-dev:amd64 7.35.0-1ubuntu2.9  amd64  development files and documentation for libcurl (OpenSSL flavour)
+ii  libcurl3:amd64             7.35.0-1ubuntu2.10 amd64  easy-to-use client-side URL transfer library (OpenSSL flavour)
+ii  libcurl3-gnutls:amd64      7.35.0-1ubuntu2.10 amd64  easy-to-use client-side URL transfer library (GnuTLS flavour)
+ii  libcurl4-openssl-dev:amd64 7.35.0-1ubuntu2.10 amd64  development files and documentation for libcurl (OpenSSL flavour)
-ii  libdbus-1-3:amd64          1.6.18-0ubuntu4.3  amd64  simple interprocess messaging system (library)
+ii  libdbus-1-3:amd64          1.6.18-0ubuntu4.4  amd64  simple interprocess messaging system (library)
```
  DIFF
  end

  before(:each) do
    File.write(cves_yaml_file, cves_yaml)
    File.write(old_receipt_file, old_receipt)
    File.write(new_receipt_file, new_receipt)

    allow(UsnReleaseNotes).to receive(:new) do |usn|
      double(text: "#{usn} with cve information")
    end
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  subject { described_class.new(cves_yaml_file, old_receipt_file, new_receipt_file) }

  describe '#release_notes' do
    it 'includes CVE information + package diff' do
      expect(subject.release_notes).to eq release_notes_output
    end
  end


  describe '#cves' do
    it 'reads the cve yml file' do
      expect(subject.cves.class).to eq Array
      expect(subject.cves.count).to eq 4
    end
  end

  describe '#unreleased_usns' do
    it 'returns the unreleased usns' do
      expect(subject.unreleased_usns).to eq ['USN-3123-1','USN-3119-1']
    end
  end

  describe '#usn_release_notes_section' do
    context 'there are unaddressed CVEs' do
      it 'returns the usn descriptions' do
        expect(subject.usn_release_notes_section).to include 'Notably, this release addresses:'
        expect(subject.usn_release_notes_section).to include 'USN-3119-1 with cve information'
        expect(subject.usn_release_notes_section).to include 'USN-3123-1 with cve information'
      end
    end

    context 'there are no unaddressed CVEs' do
      let(:cves_yaml) do <<~YAML
        ---
        - title: 'USN-3117-1: GD library vulnerabilities'
          stack_release: 1.90.0
        - title: 'USN-3116-1: DBus vulnerabilities'
          stack_release: 1.90.0
          YAML
      end

      it 'returns an empty string' do
        expect(subject.usn_release_notes_section).to eq ''
      end
    end
  end

  describe '#receipt_diff_section' do
    it 'formats the diff_correctly' do
      expect(subject.receipt_diff_section).to eq "```\n#{diff_section}```\n"
    end

    context 'the receipts are abnormal widths' do
      let(:new_receipt) { File.read('spec/fixtures/generate-cflinuxfs2-release-notes/cflinuxfs2_receipt') }
      let(:old_receipt) { File.read('spec/fixtures/generate-cflinuxfs2-release-notes/cflinuxfs2_receipt.1') }
      let(:diff_section) do <<~DIFF
-ii  eject  2.1.5+deb1+cvs20081104-13.1                amd64  ejects CDs and operates CD-Changers under Linux
+ii  eject  2.1.5+deb1+cvs20081104-13.1ubuntu0.14.04.1 amd64  ejects CDs and operates CD-Changers under Linux
        DIFF
      end

      it 'formats the diff_correctly' do
        expect(subject.receipt_diff_section).to eq "```\n#{diff_section}```\n"
      end
    end
  end

  describe '#new_packages?' do
    context 'there are new packages' do
      it 'returns true' do
        expect(subject.new_packages?).to be_truthy
      end
    end

    context 'there are not new packages' do
      let(:new_receipt) do <<~RECEIPT
      Rootfs SHASUM: fffzzzzfffffffffffffffffff

      Desired=Unknown/Install/Remove/Purge/Hold
      | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
      |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
      ||/ Name                               Version                             Architecture Description
      +++-==================================-===================================-============-===============================================================================
      ii  libcurl3:amd64                     7.35.0-1ubuntu2.9                   amd64        easy-to-use client-side URL transfer library (OpenSSL flavour)
      ii  libcurl3-gnutls:amd64              7.35.0-1ubuntu2.9                   amd64        easy-to-use client-side URL transfer library (GnuTLS flavour)
      ii  libcurl4-openssl-dev:amd64         7.35.0-1ubuntu2.9                   amd64        development files and documentation for libcurl (OpenSSL flavour)
      ii  libcwidget3                        0.5.16-3.5ubuntu1                   amd64        high-level terminal interface library for C++ (runtime files)
      ii  libdatrie1:amd64                   0.2.8-1                             amd64        Double-array trie library
      ii  libdb5.3:amd64                     5.3.28-3ubuntu3                     amd64        Berkeley v5.3 Database Libraries [runtime]
      ii  libdbus-1-3:amd64                  1.6.18-0ubuntu4.3                   amd64        simple interprocess messaging system (library)
      RECEIPT
      end

      it 'returns false' do
        expect(subject.new_packages?).to be_falsey
      end
    end
  end
end

