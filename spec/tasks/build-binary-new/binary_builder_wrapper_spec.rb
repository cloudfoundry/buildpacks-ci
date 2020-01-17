require 'tmpdir'
require_relative '../../../tasks/build-binary-new/binary_builder_wrapper'
require_relative '../../../tasks/build-binary-new/source_input'

describe 'BinaryBuilderWrapper' do
  subject { BinaryBuilderWrapper.new(runner, Dir.mktmpdir) }

  let(:runner) { double('Runner') }
  let(:source_input) { SourceInput.new('fake-name', 'fake-url', 'version', nil, '123456') }


  context 'with an extension file' do
    it 'runs the old binary builder' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=fake-name', '--version=version', '--sha256=123456', 'fake-ext-file.yml')
      subject.build(source_input, 'fake-ext-file.yml')
    end
  end

  context 'without an extension file' do
    it 'runs the old binary builder' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=fake-name', '--version=version', '--sha256=123456')
      subject.build(source_input)
    end
  end

  context 'with node' do
    let(:source_input) { SourceInput.new('node', 'fake-url', 'version', nil, '123456') }

    it 'uses node as the name it runs with' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=node', '--version=version', '--sha256=123456')
      subject.build(source_input)
    end
  end

  context 'with php7.2.X' do
    let(:source_input) { SourceInput.new('php', 'fake-url', '7.2.10', nil, '123456') }

    it 'uses php7 as the name it runs with' do
      expect(runner).to receive(:run)
        .with('./bin/binary-builder', '--name=php7', '--version=7.2.10', '--sha256=123456')
      subject.build(source_input)
    end
  end
end
