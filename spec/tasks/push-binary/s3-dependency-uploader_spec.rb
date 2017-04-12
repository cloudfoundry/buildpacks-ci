require 'fileutils'
require 'tmpdir'
require_relative '../../../tasks/push-binary/s3-dependency-uploader'

describe S3DependencyUploader do
  let(:dependency)    { 'ruby' }
  let(:bucket_name)   { 'a-bucket-name' }
  let(:task_root_dir) { Dir.mktmpdir }
  let(:artifacts_dir) { File.join(task_root_dir, 'binary-builder-artifacts') }

  subject { described_class.new(dependency, bucket_name, artifacts_dir) }

  before do
    allow(subject).to receive(:puts)
    allow(subject).to receive(:system)
  end

  after do
    FileUtils.rm_rf(task_root_dir)
  end

  context 'there are no dependencies to upload' do
    it 'writes that there are no files to upload' do
      expect(subject).to receive(:puts).with 'No files detected for upload.'

      subject.run
    end

    it 'does not upload any dependencies' do
      expect(subject).not_to receive(:system).with /aws s3 cp/

      subject.run
    end
  end

  context 'there is one dependency to upload' do
    before do
      FileUtils.mkdir_p(artifacts_dir)
      File.write(File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz'), 'xxx')
    end

    context 'the dependency does not exist on s3' do
      before do
        allow(subject).to receive(:`).with("aws s3 ls s3://a-bucket-name/dependencies/ruby/")
          .and_return('ruby/ruby-1.1.1-x64.tgz')
      end

      it 'uploads the dependency' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-2.3.4-x64.tgz"
        expect(subject).to receive(:system).with s3_copy_command

        subject.run
      end
    end

    context 'the dependency already exists on s3' do
      before do
        allow(subject).to receive(:`).with("aws s3 ls s3://a-bucket-name/dependencies/ruby/")
          .and_return("ruby/ruby-1.1.1-x64.tgz\nruby/ruby-2.3.4-x64.tgz")
      end

      it 'does not upload the dependency' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-2.3.4-x64.tgz"
        expect(subject).not_to receive(:system).with s3_copy_command

        subject.run
      end

      it 'prints a message to stdout' do
        expect(subject).to receive(:puts).with 'File ruby-2.3.4-x64.tgz has already been detected on S3. Skipping upload.'

        subject.run
      end
    end
  end

  context 'there is one .zip dependency to upload' do
    let(:dependency) { 'hwc' }

    before do
      FileUtils.mkdir_p(artifacts_dir)
      File.write(File.join(artifacts_dir, 'hwc-9.9.0-windows-amd64.zip'), 'xxx')
    end

    context 'the dependency does not exist on s3' do
      before do
        allow(subject).to receive(:`).with("aws s3 ls s3://a-bucket-name/dependencies/hwc/")
          .and_return('hwc/hwc-1.1.1-windows-amd64.zip')
      end

      it 'uploads the dependency' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'hwc-9.9.0-windows-amd64.zip')} s3://a-bucket-name/dependencies/hwc/hwc-9.9.0-windows-amd64.zip"
        expect(subject).to receive(:system).with s3_copy_command

        subject.run
      end
    end
  end

  context 'there are multiple dependencies to upload' do
    before do
      FileUtils.mkdir_p(artifacts_dir)
      File.write(File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz'), 'xxx')
      File.write(File.join(artifacts_dir, 'ruby-5.6.7-x64.tgz'), 'yyy')
    end

    context 'the dependency does not exist on s3' do
      before do
        allow(subject).to receive(:`).with("aws s3 ls s3://a-bucket-name/dependencies/ruby/")
          .and_return('ruby/ruby-1.1.1-x64.tgz')
      end

      it 'uploads both dependencies' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-2.3.4-x64.tgz"
        expect(subject).to receive(:system).with s3_copy_command

        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-5.6.7-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-5.6.7-x64.tgz"
        expect(subject).to receive(:system).with s3_copy_command

        subject.run
      end
    end

    context 'the first dependency already exists on s3' do
      before do
        allow(subject).to receive(:`).with("aws s3 ls s3://a-bucket-name/dependencies/ruby/")
          .and_return("ruby/ruby-1.1.1-x64.tgz\nruby/ruby-2.3.4-x64.tgz")
      end

      it 'does not upload the existing dependency' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-2.3.4-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-2.3.4-x64.tgz"
        expect(subject).not_to receive(:system).with s3_copy_command

        subject.run
      end

      it 'prints a message to stdout' do
        expect(subject).to receive(:puts).with 'File ruby-2.3.4-x64.tgz has already been detected on S3. Skipping upload.'

        subject.run
      end

      it 'uploads the new dependency' do
        s3_copy_command = "aws s3 cp #{File.join(artifacts_dir, 'ruby-5.6.7-x64.tgz')} s3://a-bucket-name/dependencies/ruby/ruby-5.6.7-x64.tgz"
        expect(subject).to receive(:system).with s3_copy_command

        subject.run
      end
    end
  end
end
