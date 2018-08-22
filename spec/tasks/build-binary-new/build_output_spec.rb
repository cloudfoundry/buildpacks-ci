require 'tmpdir'
require_relative '../../../tasks/build-binary-new/build_output'

describe 'BuildOutput' do
  subject { BuildOutput.new('fake-name', 'fake-version', 'fake-stack', '123', git_client, Dir.mktmpdir) }
  let(:git_client) { double('GitClient') }

  it 'adds and commits build metadata' do
    out_file = File.join('binary-builds-new', 'fake-name', 'fake-version-fake-stack.json')

    expect(git_client).to receive(:set_global_config)
      .with('user.email', 'cf-buildpacks-eng@pivotal.io')

    expect(git_client).to receive(:set_global_config)
      .with('user.name', 'CF Buildpacks Team CI Server')

    expect(git_client).to receive(:add_file)
      .with(out_file)

    expect(git_client).to receive(:safe_commit)
      .with('Build fake-name - fake-version - fake-stack [#123]')

    subject.git_add_and_commit({foo: 'bar'})

    expect(File.open(File.join(subject.base_dir, out_file)).read).to eq '{"foo":"bar"}'
  end
end