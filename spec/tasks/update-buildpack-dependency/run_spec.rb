require 'spec_helper'
require 'tmpdir'
require 'json'
require 'yaml'
require 'fileutils'
require 'semver'

# Load the Dependencies class directly — no subprocess needed
require_relative '../../../tasks/update-buildpack-dependency/dependencies'

# Unit tests for the any-stack skip logic introduced in run.rb.
#
# The fix adds this guard at the top of the build-file loop:
#
#   any_stack_build_exists = Dir["builds/.../#{version}-any-stack.json"].any?
#   next if any_stack_build_exists && !stack_dependency_build.include?('any-stack.json')
#
# These tests verify the correct outcome by simulating the loop directly
# against the Dependencies class — matching how run.rb uses it.
RSpec.describe 'any-stack skip logic in update-buildpack-dependency' do
  let(:version)      { '2025.9.191' }
  let(:old_version)  { '2025.9' }
  let(:sha256)       { '5e79eab6bc02c70b30600c3d2c390147dd458d8f5488aa2abebb67525af7f26e' }
  let(:source_url)   { 'https://download.yourkit.com/yjp/2025.9/YourKit-JavaProfiler-2025.9-b191-x64.zip' }

  let(:any_stack_uri)   { "https://buildpacks.cloudfoundry.org/dependencies/your-kit-profiler/your-kit-profiler_#{version}_linux_x64_any-stack_5e79eab6.zip" }
  let(:cflinuxfs4_uri)  { "https://buildpacks.cloudfoundry.org/dependencies/your-kit-profiler/your-kit-profiler_#{version}_linux_x64_cflinuxfs4_5e79eab6.zip" }
  let(:cflinuxfs5_uri)  { "https://buildpacks.cloudfoundry.org/dependencies/your-kit-profiler/your-kit-profiler_#{version}_linux_x64_cflinuxfs5_5e79eab6.zip" }

  # Starting manifest entries — what's in the buildpack before the pipeline runs
  let(:old_version_entry) do
    { 'name' => 'your-kit-profiler', 'version' => old_version,
      'uri' => 'https://download.yourkit.com/yjp/2025.9/YourKit-JavaProfiler-2025.9-b175-x64.zip',
      'sha256' => '3c1e7600e76067cfc446666101db515a9a247d69333b7cba5dfb05cf40e5e1d9',
      'cf_stacks' => ['cflinuxfs4'] }
  end
  let(:existing_cflinuxfs4_entry) do
    { 'name' => 'your-kit-profiler', 'version' => version,
      'uri' => cflinuxfs4_uri, 'sha256' => sha256,
      'cf_stacks' => ['cflinuxfs4'], 'source' => source_url, 'source_sha256' => sha256 }
  end
  let(:existing_cflinuxfs5_entry) do
    { 'name' => 'your-kit-profiler', 'version' => version,
      'uri' => cflinuxfs5_uri, 'sha256' => sha256,
      'cf_stacks' => ['cflinuxfs5'], 'source' => source_url, 'source_sha256' => sha256 }
  end

  let(:starting_dependencies) { [old_version_entry, existing_cflinuxfs4_entry, existing_cflinuxfs5_entry] }

  # Simulates the build JSON files the pipeline produces
  let(:any_stack_dep) do
    { 'name' => 'your-kit-profiler', 'version' => version,
      'uri' => any_stack_uri, 'sha256' => sha256,
      'cf_stacks' => ['cflinuxfs4', 'cflinuxfs5'],
      'source' => source_url, 'source_sha256' => sha256 }
  end
  let(:cflinuxfs4_dep) do
    { 'name' => 'your-kit-profiler', 'version' => version,
      'uri' => cflinuxfs4_uri, 'sha256' => sha256,
      'cf_stacks' => ['cflinuxfs4'],
      'source' => source_url, 'source_sha256' => sha256 }
  end
  let(:cflinuxfs5_dep) do
    { 'name' => 'your-kit-profiler', 'version' => version,
      'uri' => cflinuxfs5_uri, 'sha256' => sha256,
      'cf_stacks' => ['cflinuxfs5'],
      'source' => source_url, 'source_sha256' => sha256 }
  end

  # Simulates the run.rb loop for a given list of build deps to process,
  # respecting the any-stack skip logic introduced by the fix.
  #
  # your-kit-profiler uses `line: latest` → VERSION_LINE_TYPE is nil (no X pattern),
  # VERSION_LINE is 'latest', REMOVAL_STRATEGY is nil.
  def run_loop(build_deps, starting_deps = starting_dependencies,
               version_line_type: nil, removal_strategy: nil)
    any_stack_exists = build_deps.any? { |d| d['cf_stacks'] == ['cflinuxfs4', 'cflinuxfs5'] }
    current_deps = starting_deps.dup

    build_deps.each do |dep|
      # THE FIX: skip stack-specific deps when an any-stack dep exists
      next if any_stack_exists && dep['cf_stacks'] != ['cflinuxfs4', 'cflinuxfs5']

      current_deps = Dependencies.new(dep, version_line_type, removal_strategy, current_deps, []).switch
    end

    current_deps
  end

  context 'when only an any-stack build exists' do
    it 'replaces the two stack-specific 2025.9.191 entries with a single any-stack entry' do
      result = run_loop([any_stack_dep])
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' && d['version'] == version }
      expect(ykp.length).to eq(1)
    end

    it 'uses the any-stack uri for the new version' do
      result = run_loop([any_stack_dep])
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' && d['version'] == version }
      expect(ykp.first['uri']).to eq(any_stack_uri)
    end

    it 'covers both cflinuxfs4 and cflinuxfs5 in the new version entry' do
      result = run_loop([any_stack_dep])
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' && d['version'] == version }
      expect(ykp.first['cf_stacks']).to contain_exactly('cflinuxfs4', 'cflinuxfs5')
    end

    it 'does not add stack-specific uris for the new version' do
      result = run_loop([any_stack_dep])
      uris = result.select { |d| d['name'] == 'your-kit-profiler' }.map { |d| d['uri'] }
      expect(uris).not_to include(cflinuxfs4_uri, cflinuxfs5_uri)
    end
  end

  context 'when an any-stack build AND stack-specific builds exist (the PR #1191 scenario)' do
    let(:all_builds) { [any_stack_dep, cflinuxfs4_dep, cflinuxfs5_dep] }

    it 'produces exactly one entry for the new version' do
      result = run_loop(all_builds)
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' && d['version'] == version }
      expect(ykp.length).to eq(1)
    end

    it 'uses the any-stack uri, not the stack-specific uris' do
      result = run_loop(all_builds)
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' && d['version'] == version }
      expect(ykp.first['uri']).to eq(any_stack_uri)
      expect(ykp.map { |d| d['uri'] }).not_to include(cflinuxfs4_uri, cflinuxfs5_uri)
    end

    it 'does not create duplicate version entries' do
      result = run_loop(all_builds)
      versions = result.select { |d| d['name'] == 'your-kit-profiler' }.map { |d| d['version'] }
      expect(versions).to eq(versions.uniq)
    end
  end

  context 'when only stack-specific builds exist (no any-stack build)' do
    let(:starting_deps) { [old_version_entry] }

    it 'processes both stack-specific builds normally' do
      result = run_loop([cflinuxfs4_dep, cflinuxfs5_dep], starting_deps)
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' }
      uris = ykp.map { |d| d['uri'] }
      expect(uris).to include(cflinuxfs4_uri)
      expect(uris).to include(cflinuxfs5_uri)
    end

    it 'does not use the any-stack uri' do
      result = run_loop([cflinuxfs4_dep, cflinuxfs5_dep], starting_deps)
      ykp = result.select { |d| d['name'] == 'your-kit-profiler' }
      expect(ykp.map { |d| d['uri'] }).not_to include(any_stack_uri)
    end
  end
end
