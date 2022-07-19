class BinaryBuilderWrapper
  attr_reader :base_dir

  def initialize(runner, base_dir = File.join('binary-builder', 'cflinuxfs4'))
    @runner = runner
    @base_dir = base_dir
  end

  def build(source_input, extension_file = nil)
    digest_arg = if source_input.md5?
                   "--md5=#{source_input.md5}"
                 else
                   "--sha256=#{source_input.sha256}"
                 end

    version_prefix = (%w[dep glide godep].include? source_input.name) ? 'v' : ''

    Dir.chdir(@base_dir) do
      if extension_file && extension_file != ''
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{version_prefix}#{source_input.version}", digest_arg, extension_file)
      else
        @runner.run('./bin/binary-builder', "--name=#{source_input.name}", "--version=#{version_prefix}#{source_input.version}", digest_arg)
      end
    end
  end
end
