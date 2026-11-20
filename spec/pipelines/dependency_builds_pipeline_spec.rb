require 'spec_helper'
require 'open3'
require 'yaml'

# Regression test for cloudfoundry/buildpacks-ci#692: dependency update PRs
# can be lost when two update jobs push a create-pull-request-resource
# branch in the same second, because every job used the exact same
# branch_prefix ("pr-by-releng-bot"). Renders the dependency-builds pipeline
# with ytt and checks that every job has a unique branch_prefix.
#
# Requires ytt (https://carvel.dev/ytt/) on PATH.
RSpec.describe 'dependency-builds pipeline' do
  let(:repo_root) { File.expand_path('../..', __dir__) }
  let(:pipeline_dir) { File.join(repo_root, 'pipelines', 'dependency-builds') }

  def render_pipeline(pipeline_dir)
    stdout, stderr, status = Open3.capture3('ytt', '-f', pipeline_dir)
    raise "ytt failed: #{stderr}" unless status.success?

    YAML.safe_load(stdout, permitted_classes: [Date, Time])
  end

  def branch_prefixes(pipeline)
    pipeline['jobs'].flat_map do |job|
      job['plan'].select { |step| step.key?('put') && step['params'] && step['params'].key?('branch_prefix') }
                 .map { |step| step['params']['branch_prefix'] }
    end
  end

  before do
    skip 'ytt not found on PATH' unless system('which ytt > /dev/null 2>&1')
  end

  it 'gives every update job a unique branch_prefix, so same-second pushes cannot collide' do
    pipeline = render_pipeline(pipeline_dir)
    prefixes = branch_prefixes(pipeline)

    expect(prefixes).not_to be_empty

    duplicates = prefixes.tally.select { |_, count| count > 1 }.keys
    expect(duplicates).to be_empty, "duplicate branch_prefix values: #{duplicates.join(', ')}"
  end

  it 'derives the branch_prefix from the dependency, version line and buildpack' do
    pipeline = render_pipeline(pipeline_dir)
    java_openjdk_job = pipeline['jobs'].find { |job| job['name'] == 'update-openjdk-17.x.x-java' }

    put_step = java_openjdk_job['plan'].find { |step| step['put'] == 'java-pull-request' }

    expect(put_step['params']['branch_prefix']).to eq('pr-by-releng-bot-openjdk-17.x.x-java')
  end
end
