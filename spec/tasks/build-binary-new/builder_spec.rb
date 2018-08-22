# encoding: utf-8

require 'tmpdir'
require 'fileutils'
require_relative '../../../tasks/build-binary-new/builder'
require_relative '../../../tasks/build-binary-new/source_input'
require_relative '../../../tasks/build-binary-new/build_input'
require_relative '../../../tasks/build-binary-new/build_output'
require_relative '../../../tasks/build-binary-new/artifact_output'
require_relative '../../../tasks/build-binary-new/binary_builder_wrapper'

describe 'Builder' do
  context 'when building python' do
    subject { Builder.new }
    let(:binary_builder) { double(BinaryBuilderWrapper) }
    let(:source_input) { SourceInput.new('python', 'https://fake.com', '2.7.14', 'fake-md5', '') }
    let(:build_input) { double(BuildInput) }
    let(:build_output) { double(BuildOutput) }
    let(:artifact_output) { double(ArtifactOutput) }

    it 'returns metadata' do
      allow(binary_builder).to receive(:base_dir)
        .and_return '/fake-binary-builder'
      expect(binary_builder).to receive(:build)
        .with(source_input)

      expect(build_input).to receive(:tracker_story_id).and_return 'fake-story-id'
      expect(build_input).to receive(:copy_to_build_output)

      expect(build_output).to receive(:git_add_and_commit)
        .with({
          :tracker_story_id => 'fake-story-id',
          :version          => '2.7.14',
          :source           => { :url => 'https://fake.com', :md5 => 'fake-md5', :sha256 => '' },
          :sha256           => 'fake-sha256',
          :url              => 'fake-url'
        })

      expect(artifact_output).to receive(:move_dependency)
        .with('python', '/fake-binary-builder/python-2.7.14-linux-x64.tgz', 'python-2.7.14-linux-x64-cflinuxfs2', 'tgz')
        .and_return(sha256: 'fake-sha256', url: 'fake-url')

      subject.execute(binary_builder, 'cflinuxfs2', source_input, build_input, build_output, artifact_output)
    end
  end
end
