require_relative '../../../tasks/extract-dotnet-aspnetcore/aspnetcore_extractor'
require_relative '../../../tasks/build-binary-new/source_input'
require_relative '../../../tasks/build-binary-new/build_input'
require_relative '../../../tasks/build-binary-new/build_output'
require_relative '../../../tasks/build-binary-new/artifact_output'

describe 'AspnetcoreExtractor' do
  subject do
    AspnetcoreExtractor.new(
      'cflinuxfs2',
      build_input,
      build_output,
      artifact_output,
      downloader
    )
  end

  let(:build_input) { BuildInput.new('fake-story-id', 'sdk-url') }
  let(:build_output) { double(BuildOutput) }
  let(:artifact_output) { double(ArtifactOutput) }
  let(:downloader) { double(Downloader) }

  before do
    expect(downloader).to receive(:download) do |url, path|
      expect(url).to eq 'sdk-url'
      FileUtils.copy('spec/fixtures/extract-dotnet-aspnetcore/dotnet-sdk.tar.xz', path)
    end

    expect(build_input).to receive(:copy_to_build_output)
  end

  it 'should extract the Microsoft.AspNetCore.All and Microsoft.AspNetCore.App metapackages' do
    expect(artifact_output).to receive(:move_dependency)
      .with(
        'dotnet-aspnetcore',
        "#{subject.base_dir}/dotnet-aspnetcore.tar.xz",
        'dotnet-aspnetcore.2.1.2.linux-amd64-cflinuxfs2',
        'tar.xz'
      )
      .and_return(url: 'fake-url', sha256: 'fake-sha256')

    expect(build_output).to receive(:add_output)
      .with('2.1.2.json', { tracker_story_id: 'fake-story-id' })

    expect(build_output).to receive(:add_output)
      .with('2.1.2-cflinuxfs2.json',
        {
          tracker_story_id: 'fake-story-id',
          version:          '2.1.2',
          url:              'fake-url',
          sha256:           'fake-sha256'
        })

    expect(build_output).to receive(:commit_outputs)
      .with('Build dotnet-aspnetcore - 2.1.2 - cflinuxfs2 [#fake-story-id]')

    subject.run
  end
end