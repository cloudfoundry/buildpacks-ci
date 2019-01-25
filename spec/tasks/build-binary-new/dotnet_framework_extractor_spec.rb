require_relative '../../../tasks/build-binary-new/dotnet_framework_extractor'
require_relative '../../../tasks/build-binary-new/source_input'
require_relative '../../../tasks/build-binary-new/build_input'
require_relative '../../../tasks/build-binary-new/build_output'
require_relative '../../../tasks/build-binary-new/artifact_output'

describe 'DotnetFrameworkExtractor' do
  subject do
    DotnetFrameworkExtractor.new(
      sdk_dir,
      'cflinuxfs2',
      source_input,
      build_input,
      artifact_output
    )
  end

  let(:sdk_dir) {Dir.tmpdir}
  let(:source_input) {double(SourceInput)}
  let(:build_input) {double(BuildInput)}
  let(:build_output) {double(BuildOutput)}
  let(:artifact_output) {double(ArtifactOutput)}

  before(:each) do
    FileUtils.mkdir_p(File.join(sdk_dir, 'shared', 'Microsoft.NETCore.App', '3.1.3'))
    FileUtils.mkdir_p(File.join(sdk_dir, 'shared', 'Microsoft.AspNetCore.All', '2.1.2'))
    FileUtils.mkdir_p(File.join(sdk_dir, 'shared', 'Microsoft.AspNetCore.App', '2.1.2'))
    File.write(File.join(sdk_dir, 'something.txt'), 'foo')

    allow(source_input).to receive(:url).and_return('some-cli-url')
    allow(source_input).to receive(:git_commit_sha).and_return('some-git-sha')
    allow(build_input).to receive(:tracker_story_id).and_return('some-tracker-id')
  end

  context '#extract_aspnetcore' do
    before(:each) do
      allow(BuildOutput).to receive(:new).with('dotnet-aspnetcore').and_return(build_output)
      expect(artifact_output).to receive(:move_dependency)
                                   .with(
                                     'dotnet-aspnetcore',
                                     "#{subject.base_dir}/dotnet-aspnetcore.tar.xz",
                                     'dotnet-aspnetcore.2.1.2.linux-amd64-cflinuxfs2',
                                     'tar.xz'
                                   )
                                   .and_return(url: 'fake-url', sha256: 'fake-sha256')

      expect(build_output).to receive(:add_output)
                                .with('2.1.2.json', {tracker_story_id: 'some-tracker-id'})

      expect(build_output).to receive(:add_output)
                                .with('2.1.2-cflinuxfs2.json',
                                  {
                                    tracker_story_id: 'some-tracker-id',
                                    version: '2.1.2',
                                    source: {url: 'some-cli-url'},
                                    url: 'fake-url',
                                    git_commit_sha: 'some-git-sha',
                                    sha256: 'fake-sha256'
                                  })
      expect(build_output).to receive(:commit_outputs)
                                .with('Build dotnet-aspnetcore - 2.1.2 - cflinuxfs2')
    end

    it 'should extract and remove the Microsoft.AspNetCore.All and Microsoft.AspNetCore.App metapackages when told to remove frameworks' do
      expect(FileUtils).to receive(:rm_rf).with(%w(shared/Microsoft.AspNetCore.App shared/Microsoft.AspNetCore.All))
      expect(subject).not_to receive(:write_runtime_file)  # No file written for aspnetcore

      subject.extract_aspnetcore(true)
    end

    it 'should extract and keep the Microsoft.AspNetCore.All and Microsoft.AspNetCore.App metapackages when told to keep frameworks' do
      expect(FileUtils).not_to receive(:rm_rf)
      expect(subject).not_to receive(:write_runtime_file)

      subject.extract_aspnetcore(false)
    end
  end

  context '#extract_runtime' do
    before(:each) do
      allow(BuildOutput).to receive(:new).with('dotnet-runtime').and_return(build_output)
      expect(artifact_output).to receive(:move_dependency)
                                   .with(
                                     'dotnet-runtime',
                                     "#{subject.base_dir}/dotnet-runtime.tar.xz",
                                     'dotnet-runtime.3.1.3.linux-amd64-cflinuxfs2',
                                     'tar.xz'
                                   )
                                   .and_return(url: 'fake-url', sha256: 'fake-sha256')

      expect(build_output).to receive(:add_output)
                                .with('3.1.3.json', {tracker_story_id: 'some-tracker-id'})

      expect(build_output).to receive(:add_output)
                                .with('3.1.3-cflinuxfs2.json',
                                  {
                                    tracker_story_id: 'some-tracker-id',
                                    version: '3.1.3',
                                    source: {url: 'some-cli-url'},
                                    git_commit_sha: 'some-git-sha',
                                    url: 'fake-url',
                                    sha256: 'fake-sha256'
                                  })
      expect(build_output).to receive(:commit_outputs)
                                .with('Build dotnet-runtime - 3.1.3 - cflinuxfs2')
    end

    it 'should extract and remove the Microsoft.NETCore.App when told to remove frameworks' do
      expect(FileUtils).to receive(:rm_rf).with(%w(shared/Microsoft.NETCore.App)).and_return(true)
      expect(subject).to receive(:write_runtime_file).with(sdk_dir)

      subject.extract_runtime(true)
    end

    it 'should extract and keep the Microsoft.NETCore.App when told to keep frameworks' do
      expect(FileUtils).not_to receive(:rm_rf).with(%w(shared/Microsoft.NETCore.App))
      expect(subject).not_to receive(:write_runtime_file)

      subject.extract_runtime(false)
    end
  end
end
