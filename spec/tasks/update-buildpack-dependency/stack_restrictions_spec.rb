require 'spec_helper'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'yaml'
require 'semver'

require_relative '../../../lib/git-client'

RSpec.describe 'dependency update stack restrictions' do
  let(:root) { File.expand_path('../../..', __dir__) }
  let(:config) { YAML.load_file(File.join(root, 'pipelines/dependency-builds/config.yml'), permitted_classes: [Date, Time]) }

  def update_manifest(buildpack:, source:, version:, line:, entries:, build_stacks:, skip_stacks: [], build_extra: {})
    Dir.mktmpdir do |dir|
      %w[buildpack buildpack-latest-released source artifacts].each { |name| FileUtils.mkdir_p(File.join(dir, name)) }
      build_dir = File.join(dir, 'builds/binary-builds-new', source)
      FileUtils.mkdir_p(build_dir)
      manifest = { 'language' => buildpack, 'dependencies' => entries }
      %w[buildpack buildpack-latest-released].each do |name|
        File.write(File.join(dir, name, 'manifest.yml'), manifest.to_yaml)
      end
      File.write(File.join(dir, 'source/data.json'), { source: { name: source }, version: { ref: version } }.to_json)
      build_stacks.each do |stack|
        build = {
          version: version,
          url: "https://example.com/#{source}_#{version}_#{stack}.tgz",
          sha256: 'new-sha',
          source: { url: 'https://example.com/source.tgz', sha256: 'source-sha' }
        }.merge(build_extra)
        File.write(File.join(build_dir, "#{version}-#{stack}.json"), build.to_json)
      end

      env = {
        'VERSION_LINE' => line, 'VERSION_LINE_TYPE' => 'major',
        'REMOVAL_STRATEGY' => 'remove_all', 'SKIP_STACKS' => skip_stacks.join(' ')
      }
      previous = env.to_h { |key, _| [key, ENV[key]] }
      env.each { |key, value| ENV[key] = value }

      allow(GitClient).to receive(:set_global_config)
      allow(GitClient).to receive(:set_gpg_config)
      allow(GitClient).to receive(:add_file)
      allow(GitClient).to receive(:safe_commit)
      Dir.chdir(dir) do
        begin
          load File.join(root, 'tasks/update-buildpack-dependency/run.rb'), true
        rescue SystemExit => e
          raise unless e.success?
        end
      end
      YAML.load_file(File.join(dir, 'artifacts/manifest.yml'), permitted_classes: [Date, Time])
    ensure
      previous&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end

  def openjdk(version, stacks)
    {
      'name' => 'openjdk', 'version' => version,
      'uri' => "https://example.com/openjdk_#{version}_any-stack.tgz",
      'sha256' => 'old-sha', 'cf_stacks' => stacks
    }
  end

  it 'updates Ruby on cflinuxfs5 while retaining the existing cflinuxfs4 entry' do
    skip = config.dig('dependencies', 'openjdk', 'buildpacks', 'ruby', 'skip_stacks')
    result = update_manifest(buildpack: 'ruby', source: 'openjdk', version: '21.0.2',
                             line: '21.X.X', entries: [openjdk('21.0.1', %w[cflinuxfs4 cflinuxfs5])],
                             build_stacks: ['any-stack'], skip_stacks: skip)

    expect(result['dependencies']).to contain_exactly(
      a_hash_including('version' => '21.0.1', 'cf_stacks' => ['cflinuxfs4'], 'sha256' => 'old-sha'),
      a_hash_including('version' => '21.0.2', 'cf_stacks' => ['cflinuxfs5'], 'sha256' => 'new-sha')
    )
  end

  it 'still updates Java on both stacks' do
    result = update_manifest(buildpack: 'java', source: 'openjdk', version: '21.0.2',
                             line: '21.X.X', entries: [openjdk('21.0.1', %w[cflinuxfs4 cflinuxfs5])],
                             build_stacks: ['any-stack'])

    expect(result['dependencies']).to contain_exactly(
      a_hash_including('version' => '21.0.2', 'cf_stacks' => %w[cflinuxfs4 cflinuxfs5])
    )
  end

  it 'retains the Ruby cflinuxfs4 Java 8 dependency while adding Java 21 for cflinuxfs5' do
    legacy = openjdk('1.8.0', ['cflinuxfs4']).merge('name' => 'openjdk1.8-latest')
    java17 = openjdk('17.0.13', ['cflinuxfs5'])
    result = update_manifest(buildpack: 'ruby', source: 'openjdk', version: '21.0.2',
                             line: '21.X.X', entries: [legacy, java17], build_stacks: ['any-stack'],
                             skip_stacks: config.dig('dependencies', 'openjdk', 'buildpacks', 'ruby', 'skip_stacks'))

    expect(result['dependencies']).to contain_exactly(
      legacy, java17, a_hash_including('name' => 'openjdk', 'version' => '21.0.2', 'cf_stacks' => ['cflinuxfs5'])
    )
  end

  it 'rejects unknown skipped stacks' do
    expect do
      update_manifest(buildpack: 'ruby', source: 'openjdk', version: '21.0.2',
                      line: '21.X.X', entries: [], build_stacks: ['any-stack'], skip_stacks: ['cflinuxfs55'])
    end.to raise_error(/Unknown stacks in SKIP_STACKS: cflinuxfs55/)
  end

  context 'when rebuilding a PHP version that is also present for a skipped stack' do
    around do |example|
      Dir.mktmpdir do |bin|
        %w[wget tar].each do |tool|
          path = File.join(bin, tool)
          File.write(path, "#!/bin/sh\nexit 0\n")
          File.chmod(0o755, path)
        end
        original_path = ENV.fetch('PATH')
        ENV['PATH'] = "#{bin}:#{original_path}"
        example.run
      ensure
        ENV['PATH'] = original_path
      end
    end

    def php(stack, modules)
      { 'name' => 'php', 'version' => '8.3.1', 'uri' => "https://example.com/php_8.3.1_#{stack}.tgz",
        'sha256' => 'old-sha', 'cf_stacks' => [stack], 'dependencies' => modules }
    end

    it 'refreshes modules only for built stacks and leaves the skipped entry untouched' do
      skipped_entry = php('cflinuxfs4', [{ 'name' => 'existing-module' }])
      result = update_manifest(buildpack: 'php', source: 'php', version: '8.3.1', line: '8.3.X',
                               entries: [skipped_entry, php('cflinuxfs5', [])],
                               build_stacks: %w[cflinuxfs4 cflinuxfs5], skip_stacks: ['cflinuxfs4'])

      expect(result['dependencies']).to contain_exactly(
        skipped_entry,
        a_hash_including('cf_stacks' => ['cflinuxfs5'], 'sha256' => 'new-sha', 'dependencies' => [])
      )
    end
  end

  it 'does not add an empty entry when every stack of a build is skipped' do
    original = [openjdk('21.0.1', ['cflinuxfs4'])]
    result = update_manifest(buildpack: 'ruby', source: 'openjdk', version: '21.0.2',
                             line: '21.X.X', entries: original, build_stacks: ['cflinuxfs4'],
                             skip_stacks: ['cflinuxfs4'])

    expect(result['dependencies']).to eq(original)
  end

  it 'matches skip_lines case-insensitively for stack-specific builds' do
    result = update_manifest(buildpack: 'ruby', source: 'ruby', version: '2.7.8',
                             line: '2.7.X', entries: [], build_stacks: %w[cflinuxfs4 cflinuxfs5])

    expect(result['dependencies']).to contain_exactly(
      a_hash_including('version' => '2.7.8', 'cf_stacks' => ['cflinuxfs5'])
    )
  end

  it 'keeps sub-dependencies of a skipped-stack R entry when rebuilding the version' do
    r_dep = lambda do |stack, sub_version|
      { 'name' => 'r', 'version' => '4.3.1', 'uri' => "https://example.com/r_4.3.1_#{stack}.tgz",
        'sha256' => 'old-sha', 'cf_stacks' => [stack],
        'dependencies' => [{ 'name' => 'forecast', 'version' => sub_version }] }
    end
    skipped_entry = r_dep.call('cflinuxfs4', '8.20')
    new_sub_deps = { sub_dependencies: { 'forecast' => { version: '8.21', source: { url: 'https://example.com/forecast.tgz', sha256: 'sub-sha' } } } }

    result = update_manifest(buildpack: 'r', source: 'r', version: '4.3.1', line: '4.3.X',
                             entries: [skipped_entry, r_dep.call('cflinuxfs5', '8.20')],
                             build_stacks: %w[cflinuxfs4 cflinuxfs5], skip_stacks: ['cflinuxfs4'],
                             build_extra: new_sub_deps)

    expect(result['dependencies']).to contain_exactly(
      skipped_entry,
      a_hash_including('cf_stacks' => ['cflinuxfs5'], 'sha256' => 'new-sha',
                       'dependencies' => [a_hash_including('name' => 'forecast', 'version' => '8.21')])
    )
  end
end
