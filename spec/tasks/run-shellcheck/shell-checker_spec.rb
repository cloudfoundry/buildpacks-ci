require 'spec_helper'
require_relative '../../../tasks/run-shellcheck/shell-checker'

describe ShellChecker do
  describe 'finding scripts to check' do
    let(:fixture_dir) { File.join(__dir__, 'fixtures/file-identification') }
    subject { ShellChecker.new.check_shell_files(directory: fixture_dir) }

    it 'finds files with a .sh extension' do
      expect(subject.keys).to include("#{fixture_dir}/no_shebang.sh", "#{fixture_dir}/shebang_with_extension.sh")
    end

    it 'finds files with a bash shebang line' do
      expect(subject.keys).to include("#{fixture_dir}/shebang_without_sh_extension", "#{fixture_dir}/shebang_with_extension.sh")
    end

    it 'only finds each file once' do
      expect(subject.keys).to contain_exactly("#{fixture_dir}/shebang_without_sh_extension", "#{fixture_dir}/shebang_with_extension.sh", "#{fixture_dir}/no_shebang.sh")
    end

    it 'skips dotfiles' do
      expect(subject.keys).to_not include("#{fixture_dir}/.dotfile")
    end

    it 'skips empty files' do
      expect(subject.keys).to_not include("#{fixture_dir}/empty-file-which-should-be-skipped.sh")
    end

    it 'skips binary files that cause UTF-8 errors' do
      expect(subject.keys).to_not include("#{fixture_dir}/compressed-file-which-should-be-ignored.tar.gz")
    end
  end

  describe 'interpreting results' do
    let(:fixture_dir) { File.join(__dir__, 'fixtures/scripts-with-problems') }
    subject { ShellChecker.new.check_shell_files(directory: fixture_dir) }

    it 'groups the output from shellchecker by file' do
      expect(subject["#{fixture_dir}/script-with-error-sc2006.sh"]).to match /SC2006:/
    end
  end
end
