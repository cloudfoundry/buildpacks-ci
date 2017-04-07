require_relative 'buildpacks-ci-configuration'

class BuildpacksCIPipelineUpdateCommand
  def run!(concourse_target_name:, pipeline_name:, config_generation_command:, pipeline_variable_filename: "", options:)

    buildpacks_configuration = BuildpacksCIConfiguration.new

    pipeline_prefix = ENV.fetch('PIPELINE_PREFIX', '')
    pipeline_prefix += "#{options[:stack]}-" unless options[:stack].nil?

    secrets_file = ENV.fetch('CONCOURSE_SECRETS_FILE', nil)

    if secrets_file.nil?
      puts 'Please set CONCOURSE_SECRETS_FILE to the secrets location'
      exit 1
    end

    text_to_include = options[:include]
    text_to_exclude = options[:exclude]
    return if options.has_key?(:include) && !pipeline_name.include?(text_to_include)
    return if options.has_key?(:exclude) && pipeline_name.include?(text_to_exclude)

    if pipeline_name == 'binary-builder' and options[:stack].nil?
       raise "The binary-builder pipeline requires the --stack option"
    end

    stack_command = ''
    stack_command = "cat #{options[:stack]}-stack-config.yaml" unless options[:stack].nil?

    puts "   #{pipeline_name} pipeline"

    secrets_cmd = [
      buildpacks_configuration.concourse_private_filename,
      buildpacks_configuration.deployments_buildpacks_filename,
      buildpacks_configuration.repos_private_keys_filename,
      buildpacks_configuration.git_repos_private_keys_filename,
      buildpacks_configuration.git_repos_private_keys_two_filename,
      buildpacks_configuration.git_repos_private_keys_three_filename,
      buildpacks_configuration.bosh_release_private_keys_filename,
      buildpacks_configuration.dockerhub_cflinuxfs2_credentials_filename
    ].map { |name| "lpass show #{name} --notes"}.join(' && ')

    pipeline_specific_config = ""
    pipeline_specific_config ="--load-vars-from=#{pipeline_variable_filename}" unless pipeline_variable_filename.empty?
    fly_cmd = %{bash -c "fly \
      --target=#{concourse_target_name} \
      set-pipeline \
      --pipeline=#{pipeline_prefix}#{pipeline_name} \
      --config=<(#{config_generation_command}) \
      --load-vars-from=<(gpg -d --no-tty #{secrets_file} 2> /dev/null; cat secrets-map.yaml; #{stack_command}) \
      --load-vars-from=public-config.yml \
    #{pipeline_specific_config}
    "}

    system "#{fly_cmd}"
  end
end
