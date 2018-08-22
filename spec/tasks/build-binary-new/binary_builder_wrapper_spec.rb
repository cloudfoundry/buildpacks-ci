require 'tmpdir'
require_relative '../../../tasks/build-binary-new/binary_builder_wrapper'
require_relative '../../../tasks/build-binary-new/source_input'

describe 'BinaryBuilderWrapper' do
  let(:runner) { double('Runner') }
  let(:source_input) { SourceInput.new('fake-name', 'fake-url', 'version', nil, '123456') }
  subject { BinaryBuilderWrapper.new(runner, Dir.mktmpdir) }

  context 'with an extension file' do
    it 'should run the old binary builder' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=fake-name', '--version=version', '--sha256=123456', 'fake-ext-file.yml')
      subject.build(source_input, 'fake-ext-file.yml')
    end
  end

  context 'without an extension file' do
    it 'should run the old binary builder' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=fake-name', '--version=version', '--sha256=123456')
      subject.build(source_input)
    end
  end
end