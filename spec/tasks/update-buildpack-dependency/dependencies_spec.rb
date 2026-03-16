require 'spec_helper'
require 'semver'

require_relative '../../../tasks/update-buildpack-dependency/dependencies'

# Comprehensive unit tests for Dependencies#switch.
#
# Real-world dependency patterns seen in CF buildpack manifests:
#
#   any-stack deps  — one entry per version, cf_stacks lists ALL supported stacks.
#                     URI contains "any-stack" in filename.
#                     Examples: yarn, bundler, rubygems, bower, dotnet-sdk/runtime/aspnetcore
#
#   stack-specific  — one entry per version PER STACK, cf_stacks is a single-element array.
#                     URI contains the stack name in filename.
#                     Examples: node, python, ruby, go
#
# The key invariant this class must uphold:
#   - any-stack deps must never produce duplicate version entries, even when the
#     set of supported stacks changes (e.g. cflinuxfs3+cflinuxfs4 → cflinuxfs4+cflinuxfs5)
#   - stack-specific deps legitimately have multiple entries for the same version
#     (one per stack) and must not be incorrectly collapsed
RSpec.describe Dependencies do
  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------
  def make_dep(name:, version:, stacks:, uri_suffix: nil)
    uri_suffix ||= stacks.length > 1 ? 'any-stack' : stacks.first
    {
      'name'         => name,
      'version'      => version,
      'uri'          => "https://buildpacks.cloudfoundry.org/dependencies/#{name}/#{name}_#{version}_linux_noarch_#{uri_suffix}_abc12345.tgz",
      'sha256'       => 'abc12345' * 8,
      'cf_stacks'    => stacks,
      'source'       => "https://example.com/#{name}-#{version}.tar.gz",
      'source_sha256' => 'def67890' * 8
    }
  end

  def switch(new_dep, existing_deps, line: nil, removal_strategy: nil, latest_released: [])
    Dependencies.new(new_dep, line, removal_strategy, existing_deps, latest_released).switch
  end

  # ---------------------------------------------------------------------------
  # ANY-STACK dependencies (yarn, bundler, rubygems, bower, dotnet-*, …)
  # ---------------------------------------------------------------------------
  describe 'any-stack dependency behaviour' do
    let(:dep_name) { 'yarn' }

    # This is the exact scenario that caused nodejs-buildpack PR #886 to fail.
    #
    # Before cflinuxfs5 was added to BUILD_STACKS, the any-stack build produced
    # a dep with cf_stacks: [cflinuxfs4] only, so the existing cflinuxfs4+cflinuxfs3
    # entry was correctly recognised as a match (cflinuxfs4 ⊆ {cflinuxfs4}).
    #
    # After cflinuxfs5 was added, the any-stack build now produces
    # cf_stacks: [cflinuxfs4, cflinuxfs5].  The subset check
    #   ['cflinuxfs4','cflinuxfs3'] - ['cflinuxfs4','cflinuxfs5'] = ['cflinuxfs3'] ≠ []
    # returns false, so the old entry is NOT recognised as a match, stays in the
    # manifest, and the new entry is appended → two yarn 1.22.22 entries both
    # covering cflinuxfs4 → buildpack fails with "more than one version of yarn found".
    context 'when stacks evolve: existing entry has cflinuxfs3+cflinuxfs4, new build covers cflinuxfs4+cflinuxfs5 (PR #886 bug)' do
      # Real URIs from the nodejs-buildpack PR #886 — same version, different content
      # hashes because the tarball was rebuilt for the new stack set.
      let(:existing_entry) do
        make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs3]).merge(
          'uri'    => 'https://buildpacks.cloudfoundry.org/dependencies/yarn/yarn_1.22.22_linux_noarch_any-stack_4911d0a6.tgz',
          'sha256' => '4911d0a6ccea0b992648fbba16a687917511233552ab87cb8ff4b80259ddfac2'
        )
      end
      let(:new_dep) do
        make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]).merge(
          'uri'    => 'https://buildpacks.cloudfoundry.org/dependencies/yarn/yarn_1.22.22_linux_noarch_any-stack_df064301.tgz',
          'sha256' => 'df064301db0f1c0cac4ecf195103495de55e9b06226a38d867b1839103137916'
        )
      end

      subject { switch(new_dep, [existing_entry]) }

      it 'produces exactly one entry for the version' do
        expect(subject.count { |d| d['name'] == dep_name && d['version'] == '1.22.22' }).to eq(1)
      end

      it 'replaces the old entry with the new one' do
        entry = subject.find { |d| d['name'] == dep_name && d['version'] == '1.22.22' }
        expect(entry['cf_stacks']).to contain_exactly('cflinuxfs4', 'cflinuxfs5')
      end

      it 'uses the new URI' do
        entry = subject.find { |d| d['name'] == dep_name && d['version'] == '1.22.22' }
        expect(entry['uri']).to eq(new_dep['uri'])
      end

      it 'does not keep the old URI' do
        expect(subject.map { |d| d['uri'] }).not_to include(existing_entry['uri'])
      end
    end

    context 'when stacks evolve: existing entry has only cflinuxfs4, new build covers cflinuxfs4+cflinuxfs5' do
      let(:existing_entry) { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4]) }
      let(:new_dep)        { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]) }

      subject { switch(new_dep, [existing_entry]) }

      it 'produces exactly one entry for the version' do
        expect(subject.count { |d| d['name'] == dep_name && d['version'] == '1.22.22' }).to eq(1)
      end

      it 'updates the stacks to include cflinuxfs5' do
        entry = subject.find { |d| d['name'] == dep_name }
        expect(entry['cf_stacks']).to contain_exactly('cflinuxfs4', 'cflinuxfs5')
      end
    end

    context 'when rebuilding the same version with the same stacks (cflinuxfs4+cflinuxfs5)' do
      let(:existing_entry) { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]) }
      let(:new_dep) do
        make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]).merge(
          'uri' => 'https://buildpacks.cloudfoundry.org/dependencies/yarn/yarn_1.22.22_linux_noarch_any-stack_newsha123.tgz',
          'sha256' => 'newsha123' * 8
        )
      end

      subject { switch(new_dep, [existing_entry]) }

      it 'produces exactly one entry' do
        expect(subject.count { |d| d['name'] == dep_name }).to eq(1)
      end

      it 'replaces with the new URI and sha256' do
        expect(subject.first['uri']).to eq(new_dep['uri'])
        expect(subject.first['sha256']).to eq(new_dep['sha256'])
      end
    end

    context 'when a newer version arrives (latest line)' do
      let(:old_entry) { make_dep(name: dep_name, version: '1.22.21', stacks: %w[cflinuxfs4 cflinuxfs3]) }
      let(:new_dep)   { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]) }

      subject { switch(new_dep, [old_entry], line: nil, removal_strategy: nil) }

      it 'adds the new version' do
        expect(subject.map { |d| d['version'] }).to include('1.22.22')
      end

      it 'removes the old version (no keep strategy)' do
        expect(subject.map { |d| d['version'] }).not_to include('1.22.21')
      end

      it 'has exactly one entry' do
        expect(subject.count { |d| d['name'] == dep_name }).to eq(1)
      end
    end

    context 'when multiple versions exist and a newer one arrives (keep_latest_released strategy)' do
      let(:v1) { make_dep(name: dep_name, version: '1.22.20', stacks: %w[cflinuxfs4 cflinuxfs3]) }
      let(:v2) { make_dep(name: dep_name, version: '1.22.21', stacks: %w[cflinuxfs4 cflinuxfs3]) }
      let(:new_dep) { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]) }

      subject { switch(new_dep, [v1, v2], line: nil, removal_strategy: 'keep_latest_released', latest_released: [v2]) }

      it 'adds the new version' do
        expect(subject.map { |d| d['version'] }).to include('1.22.22')
      end

      it 'retains the latest released version' do
        expect(subject.map { |d| d['version'] }).to include('1.22.21')
      end

      it 'removes older versions beyond keep policy' do
        expect(subject.map { |d| d['version'] }).not_to include('1.22.20')
      end

      it 'never produces duplicate versions' do
        versions = subject.select { |d| d['name'] == dep_name }.map { |d| d['version'] }
        expect(versions).to eq(versions.uniq)
      end
    end

    context 'when the manifest has two same-version entries due to a previous bug' do
      # Simulates the broken state that PR #886 introduced: two yarn 1.22.22 entries
      # both covering cflinuxfs4.  The next pipeline run should heal the manifest.
      let(:old_entry) { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs3]) }
      let(:new_entry) { make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]) }
      let(:healed_dep) do
        make_dep(name: dep_name, version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5]).merge(
          'uri' => 'https://buildpacks.cloudfoundry.org/dependencies/yarn/yarn_1.22.22_linux_noarch_any-stack_healed.tgz'
        )
      end

      subject { switch(healed_dep, [old_entry, new_entry]) }

      it 'produces exactly one entry, healing the duplicate' do
        expect(subject.count { |d| d['name'] == dep_name && d['version'] == '1.22.22' }).to eq(1)
      end

      it 'uses the new URI' do
        expect(subject.first['uri']).to eq(healed_dep['uri'])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # STACK-SPECIFIC dependencies (node, python, ruby, go, …)
  # ---------------------------------------------------------------------------
  describe 'stack-specific dependency behaviour' do
    let(:dep_name) { 'node' }

    context 'when adding cflinuxfs5 entry for a version that already has cflinuxfs4 and cflinuxfs3 entries' do
      let(:fs3_entry) { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs3]) }
      let(:fs4_entry) { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs4]) }
      let(:fs5_dep)   { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs5]) }

      subject { switch(fs5_dep, [fs3_entry, fs4_entry], line: 'minor') }

      it 'adds the cflinuxfs5 entry' do
        stacks = subject.select { |d| d['name'] == dep_name && d['version'] == '22.22.0' }
                        .flat_map { |d| d['cf_stacks'] }
        expect(stacks).to include('cflinuxfs5')
      end

      it 'keeps the cflinuxfs4 entry intact' do
        entry = subject.find { |d| d['name'] == dep_name && d['cf_stacks'] == %w[cflinuxfs4] }
        expect(entry).not_to be_nil
        expect(entry['uri']).to eq(fs4_entry['uri'])
      end

      it 'keeps the cflinuxfs3 entry intact' do
        entry = subject.find { |d| d['name'] == dep_name && d['cf_stacks'] == %w[cflinuxfs3] }
        expect(entry).not_to be_nil
        expect(entry['uri']).to eq(fs3_entry['uri'])
      end

      it 'results in three separate stack entries for the version' do
        entries = subject.select { |d| d['name'] == dep_name && d['version'] == '22.22.0' }
        expect(entries.length).to eq(3)
      end
    end

    context 'when rebuilding a single-stack entry' do
      let(:fs4_entry) { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs4]) }
      let(:fs5_entry) { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs5]) }
      let(:new_fs4_dep) do
        make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs4]).merge(
          'uri'    => 'https://buildpacks.cloudfoundry.org/dependencies/node/node_22.22.0_linux_x64_cflinuxfs4_newsha.tgz',
          'sha256' => 'newsha' * 10
        )
      end

      subject { switch(new_fs4_dep, [fs4_entry, fs5_entry], line: 'minor') }

      it 'replaces only the cflinuxfs4 entry' do
        entry = subject.find { |d| d['name'] == dep_name && d['cf_stacks'] == %w[cflinuxfs4] }
        expect(entry['uri']).to eq(new_fs4_dep['uri'])
      end

      it 'leaves the cflinuxfs5 entry untouched' do
        entry = subject.find { |d| d['name'] == dep_name && d['cf_stacks'] == %w[cflinuxfs5] }
        expect(entry['uri']).to eq(fs5_entry['uri'])
      end

      it 'keeps exactly two entries for the version' do
        entries = subject.select { |d| d['name'] == dep_name && d['version'] == '22.22.0' }
        expect(entries.length).to eq(2)
      end
    end

    # node uses major version lines (20.X.X, 22.X.X) — a patch update within the
    # same major line (22.21.0 → 22.22.0) replaces the old cflinuxfs4 entry but
    # leaves the cflinuxfs5 entry (which hasn't been rebuilt yet) intact.
    context 'when a patch update arrives for one stack (major version line)' do
      let(:old_fs4) { make_dep(name: dep_name, version: '22.21.0', stacks: %w[cflinuxfs4]) }
      let(:old_fs5) { make_dep(name: dep_name, version: '22.21.0', stacks: %w[cflinuxfs5]) }
      let(:new_fs4) { make_dep(name: dep_name, version: '22.22.0', stacks: %w[cflinuxfs4]) }

      subject { switch(new_fs4, [old_fs4, old_fs5], line: 'major') }

      it 'adds the new cflinuxfs4 entry' do
        expect(subject.map { |d| [d['version'], d['cf_stacks']] })
          .to include(['22.22.0', %w[cflinuxfs4]])
      end

      it 'removes the old cflinuxfs4 entry for the same major line' do
        expect(subject.map { |d| [d['version'], d['cf_stacks']] })
          .not_to include(['22.21.0', %w[cflinuxfs4]])
      end

      it 'keeps the old cflinuxfs5 entry (different stack, not yet updated)' do
        expect(subject.map { |d| [d['version'], d['cf_stacks']] })
          .to include(['22.21.0', %w[cflinuxfs5]])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # General invariants that apply to BOTH types
  # ---------------------------------------------------------------------------
  describe 'general invariants' do
    it 'never produces two entries with the same name, version, and cf_stacks' do
      existing = [
        make_dep(name: 'yarn', version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs3]),
        make_dep(name: 'yarn', version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5])
      ]
      new_dep = make_dep(name: 'yarn', version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5])

      result = switch(new_dep, existing)
      tuples = result.map { |d| [d['name'], d['version'], d['cf_stacks'].sort] }
      expect(tuples.uniq).to eq(tuples)
    end

    it 'sorts output by name then version' do
      deps = [
        make_dep(name: 'yarn', version: '1.22.20', stacks: %w[cflinuxfs4]),
        make_dep(name: 'yarn', version: '1.22.22', stacks: %w[cflinuxfs4])
      ]
      new_dep = make_dep(name: 'yarn', version: '1.22.23', stacks: %w[cflinuxfs4 cflinuxfs5])

      result = switch(new_dep, deps, removal_strategy: 'keep_all')
      versions = result.map { |d| d['version'] }
      expect(versions).to eq(versions.sort_by { |v| SemVer.parse(v) })
    end

    it 'does not modify entries for other dependency names' do
      node_entry = make_dep(name: 'node',   version: '22.22.0', stacks: %w[cflinuxfs4])
      yarn_entry = make_dep(name: 'yarn',   version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs3])
      new_yarn   = make_dep(name: 'yarn',   version: '1.22.22', stacks: %w[cflinuxfs4 cflinuxfs5])

      result = switch(new_yarn, [node_entry, yarn_entry])
      node_result = result.find { |d| d['name'] == 'node' }
      expect(node_result).to eq(node_entry)
    end
  end
end
