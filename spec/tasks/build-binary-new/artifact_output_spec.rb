require 'tmpdir'
require_relative '../../../tasks/build-binary-new/artifact_output'

describe 'ArtifactOutput' do
  subject { ArtifactOutput.new(Dir.mktmpdir) }

  let(:old_file_path) do
    file_path = File.join(Dir.mktmpdir, 'fake_dep.tar.gz')
    File.write(file_path, 'some test data')
    file_path
  end

  it 'should rename the dep and move it into the artifact directory' do
    result = subject.move_dependency('fake-dep', old_file_path, 'fake_dep-1.0.1', 'tar.gz')
    expect(result[:sha256]).to eq 'f70c5e847d0ea29088216d81d628df4b4f68f3ccabb2e4031c09cc4d129ae216'
    expect(result[:url]).to eq 'https://buildpacks.cloudfoundry.org/dependencies/fake-dep/fake_dep-1.0.1-f70c5e84.tar.gz'
    expect(File.file?(File.join(subject.base_dir, 'fake_dep-1.0.1-f70c5e84.tar.gz'))).to be true
  end
end
