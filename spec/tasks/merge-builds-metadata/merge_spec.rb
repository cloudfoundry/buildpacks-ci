require 'spec_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
require 'open3'

MERGE_SH = File.expand_path('../../../tasks/merge-builds-metadata/merge.sh', __dir__)

RSpec.describe 'merge-builds-metadata/merge.sh' do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Initialise a bare git repo at +path+ with an empty initial commit.
  def init_git_repo(path, email: 'test@example.com', name: 'Test')
    FileUtils.mkdir_p(path)
    cmds = [
      %w[git init],
      %W[git config user.email #{email}],
      %W[git config user.name #{name}],
      %w[git commit --allow-empty -m initial]
    ]
    cmds.each { |cmd| system(*cmd, chdir: path, out: '/dev/null', err: '/dev/null') }
  end

  # Write a realistic builds JSON file into
  # +base+/binary-builds-new/+dep+/+version+-+stack+.json
  def write_builds_json(base, dep:, version:, stack:, sha256: 'abc123')
    dir = File.join(base, 'binary-builds-new', dep)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{version}-#{stack}.json"), JSON.generate(
                                                             version: version,
                                                             url: "https://buildpacks.cloudfoundry.org/dependencies/#{dep}/#{dep}_#{version}_#{stack}.tgz",
                                                             sha256: sha256,
                                                             source: {},
                                                             source_sha256: sha256,
                                                             sub_dependencies: {}
                                                           ))
  end

  # Commit all staged changes in +path+.
  def git_commit_all(path, message: 'add files')
    system('git', 'add', '.', chdir: path, out: '/dev/null', err: '/dev/null')
    system('git', 'commit', '-m', message, chdir: path, out: '/dev/null', err: '/dev/null')
  end

  # Return the number of commits in +path+ (excluding the empty initial one).
  def commit_count(path)
    `git -C #{path} rev-list --count HEAD`.strip.to_i
  end

  # Return the files changed in the most recent commit of +path+.
  def last_commit_files(path)
    `git -C #{path} diff-tree --no-commit-id -r --name-only HEAD`.strip.split("\n")
  end

  # Run merge.sh inside +workdir+, return [stdout, stderr, Process::Status].
  def run_merge(workdir)
    env = {
      'GIT_USER_EMAIL' => 'ci@example.com',
      'GIT_USER_NAME' => 'CI Bot'
    }
    Open3.capture3(env, 'bash', MERGE_SH, chdir: workdir)
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  around do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir
      example.run
    end
  end

  # Concourse layout:
  #
  #   builds/                        ← git resource (seed)
  #   <stack>-builds-metadata/       ← task output from build-binary (one per stack)
  #     binary-builds-new/<dep>/
  #       <version>-<stack>.json
  #   merged-builds-metadata/        ← task output (initially a clone of builds/)

  def setup_builds_repo(existing_files: [])
    builds = File.join(@tmpdir, 'builds')
    init_git_repo(builds)
    existing_files.each { |f| f.call(builds) }
    git_commit_all(builds, message: 'seed') unless existing_files.empty?
    builds
  end

  def setup_merged_repo
    merged = File.join(@tmpdir, 'merged-builds-metadata')
    # Concourse seeds the output dir from the builds resource via rsync —
    # simulate by cloning builds/ into merged-builds-metadata/.
    system('git', 'clone', File.join(@tmpdir, 'builds'), merged,
           out: '/dev/null', err: '/dev/null')
    merged
  end

  def setup_stack_dir(stack, dep:, version:, sha256: 'abc123')
    stack_dir = File.join(@tmpdir, "#{stack}-builds-metadata")
    # Stack dirs are plain task output dirs — NOT git repos, just copied files.
    write_builds_json(stack_dir, dep: dep, version: version, stack: stack, sha256: sha256)
    stack_dir
  end

  # ---------------------------------------------------------------------------
  # Scenario 1: happy path — two stacks, both new JSONs → one atomic commit
  # ---------------------------------------------------------------------------
  context 'when two stacks each have a new JSON file' do
    before do
      setup_builds_repo
      setup_merged_repo
      setup_stack_dir('cflinuxfs4', dep: 'node', version: '22.0.0')
      setup_stack_dir('cflinuxfs5', dep: 'node', version: '22.0.0')
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'produces exactly one new commit in merged-builds-metadata' do
      before = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      run_merge(@tmpdir)
      after = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(after - before).to eq(1)
    end

    it 'commits both stack JSON files in a single commit' do
      run_merge(@tmpdir)
      files = last_commit_files(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(files).to include('binary-builds-new/node/22.0.0-cflinuxfs4.json')
      expect(files).to include('binary-builds-new/node/22.0.0-cflinuxfs5.json')
    end

    it 'writes the correct content for each stack' do
      run_merge(@tmpdir)
      merged = File.join(@tmpdir, 'merged-builds-metadata')
      %w[cflinuxfs4 cflinuxfs5].each do |stack|
        path = File.join(merged, 'binary-builds-new', 'node', "22.0.0-#{stack}.json")
        expect(File.exist?(path)).to be true
        data = JSON.parse(File.read(path))
        expect(data['version']).to eq('22.0.0')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 2: idempotency — both JSONs already in builds/ seed → no new commit
  # ---------------------------------------------------------------------------
  context 'when both stack JSONs are already present in the builds seed' do
    before do
      setup_builds_repo(existing_files: [
                          ->(p) { write_builds_json(p, dep: 'node', version: '22.0.0', stack: 'cflinuxfs4') },
                          ->(p) { write_builds_json(p, dep: 'node', version: '22.0.0', stack: 'cflinuxfs5') }
                        ])
      setup_merged_repo
      setup_stack_dir('cflinuxfs4', dep: 'node', version: '22.0.0')
      setup_stack_dir('cflinuxfs5', dep: 'node', version: '22.0.0')
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'makes no new commit' do
      before = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      run_merge(@tmpdir)
      after = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(after).to eq(before)
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 3: race condition — cflinuxfs4 already committed, cflinuxfs5 is new
  # ---------------------------------------------------------------------------
  context 'when one stack JSON is already in builds/ and the other is new (race condition)' do
    before do
      setup_builds_repo(existing_files: [
                          ->(p) { write_builds_json(p, dep: 'node', version: '22.0.0', stack: 'cflinuxfs4') }
                        ])
      setup_merged_repo
      setup_stack_dir('cflinuxfs4', dep: 'node', version: '22.0.0')
      setup_stack_dir('cflinuxfs5', dep: 'node', version: '22.0.0')
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'produces exactly one new commit' do
      before = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      run_merge(@tmpdir)
      after = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(after - before).to eq(1)
    end

    it 'commits only the new cflinuxfs5 JSON' do
      run_merge(@tmpdir)
      files = last_commit_files(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(files).to     include('binary-builds-new/node/22.0.0-cflinuxfs5.json')
      expect(files).not_to include('binary-builds-new/node/22.0.0-cflinuxfs4.json')
    end

    it 'retains the existing cflinuxfs4 JSON in the repo' do
      run_merge(@tmpdir)
      path = File.join(@tmpdir, 'merged-builds-metadata',
                       'binary-builds-new', 'node', '22.0.0-cflinuxfs4.json')
      expect(File.exist?(path)).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 4: one stack dir has no binary-builds-new/ subdir → skipped
  # ---------------------------------------------------------------------------
  context 'when one stack dir has no binary-builds-new/ subdir' do
    before do
      setup_builds_repo
      setup_merged_repo
      # cflinuxfs4 dir exists but has no binary-builds-new/ inside
      FileUtils.mkdir_p(File.join(@tmpdir, 'cflinuxfs4-builds-metadata'))
      setup_stack_dir('cflinuxfs5', dep: 'node', version: '22.0.0')
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'still commits the stack that does have files' do
      run_merge(@tmpdir)
      files = last_commit_files(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(files).to include('binary-builds-new/node/22.0.0-cflinuxfs5.json')
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 5: no *-builds-metadata dirs at all → exits cleanly, no commit
  # ---------------------------------------------------------------------------
  context 'when there are no stack build dirs at all' do
    before do
      setup_builds_repo
      setup_merged_repo
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'makes no new commit' do
      before = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      run_merge(@tmpdir)
      after = commit_count(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(after).to eq(before)
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 6: .git/ not clobbered — merged-builds-metadata keeps its own identity
  # ---------------------------------------------------------------------------
  context 'when merge.sh runs, merged-builds-metadata keeps its own git identity' do
    before do
      setup_builds_repo
      setup_merged_repo
      setup_stack_dir('cflinuxfs4', dep: 'node', version: '22.0.0')
    end

    it 'uses the GIT_USER_EMAIL env var for the commit author' do
      run_merge(@tmpdir)
      author = `git -C #{File.join(@tmpdir, 'merged-builds-metadata')} log -1 --format='%ae'`.strip
      expect(author).to eq('ci@example.com')
    end

    it 'does not use the builds/ repo identity' do
      run_merge(@tmpdir)
      author = `git -C #{File.join(@tmpdir, 'merged-builds-metadata')} log -1 --format='%ae'`.strip
      expect(author).not_to eq('test@example.com')
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 7: future stack (stack-agnostic) — works with any stack name
  # ---------------------------------------------------------------------------
  context 'when a new stack name is introduced (e.g. cflinuxfs6)' do
    before do
      setup_builds_repo(existing_files: [
                          ->(p) { write_builds_json(p, dep: 'python', version: '3.12.0', stack: 'cflinuxfs4') },
                          ->(p) { write_builds_json(p, dep: 'python', version: '3.12.0', stack: 'cflinuxfs5') }
                        ])
      setup_merged_repo
      setup_stack_dir('cflinuxfs4', dep: 'python', version: '3.12.0')
      setup_stack_dir('cflinuxfs5', dep: 'python', version: '3.12.0')
      setup_stack_dir('cflinuxfs6', dep: 'python', version: '3.12.0')
    end

    it 'exits successfully' do
      _, _, status = run_merge(@tmpdir)
      expect(status).to be_success
    end

    it 'commits only the new cflinuxfs6 JSON' do
      run_merge(@tmpdir)
      files = last_commit_files(File.join(@tmpdir, 'merged-builds-metadata'))
      expect(files).to     include('binary-builds-new/python/3.12.0-cflinuxfs6.json')
      expect(files).not_to include('binary-builds-new/python/3.12.0-cflinuxfs4.json')
      expect(files).not_to include('binary-builds-new/python/3.12.0-cflinuxfs5.json')
    end

    it 'retains all existing stack JSONs in the repo' do
      run_merge(@tmpdir)
      merged = File.join(@tmpdir, 'merged-builds-metadata')
      %w[cflinuxfs4 cflinuxfs5 cflinuxfs6].each do |stack|
        path = File.join(merged, 'binary-builds-new', 'python', "3.12.0-#{stack}.json")
        expect(File.exist?(path)).to be true
      end
    end
  end
end
