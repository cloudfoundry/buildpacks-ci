require 'tmpdir'
require_relative '../../../tasks/build-binary-new/build_output'

describe 'BuildOutput' do
  subject { BuildOutput.new('fake-name', git_client, Dir.mktmpdir) }
  let(:git_client) { double('GitClient') }

  it 'should add an output' do
    expect(git_client).to receive(:add_file)
      .with('test_file')

    subject.add_output('test_file', { A: '1', B: '2', C: '3' })

    expect(File.open(File.join(subject.base_dir, 'test_file')).read).to eq '{"A":"1","B":"2","C":"3"}'
  end

  it 'should commit outputs' do
    expect(git_client).to receive(:set_global_config)
      .with('user.email', 'cf-buildpacks-eng@pivotal.io')

    expect(git_client).to receive(:set_global_config)
      .with('user.name', 'CF Buildpacks Team CI Server')

    expect(git_client).to receive(:safe_commit)
      .with('test message')

    subject.commit_outputs('test message')
  end
end