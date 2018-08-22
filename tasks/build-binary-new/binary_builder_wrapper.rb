class BinaryBuilderWrapper
  attr_reader :base_dir

  def initialize(runner, base_dir = 'binary-builder')
    @base_dir = base_dir
    @runner = runner
  end

  def build(source_input, extension_file = nil)
    digest_arg = if source_input.md5?
      "--md5=#{source_input.md5}"
    elsif source_input.sha256?
      "--sha256=#{source_input.sha256}"
    else
      '--sha256=' # because php5 doesn't have a sha
    end

    Dir.chdir(@base_dir) do
      if extension_file && extension_file != ''
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{source_input.version}", digest_arg, extension_file)
      else
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{source_input.version}", digest_arg)
      end
    end
  end
end