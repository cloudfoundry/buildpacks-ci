require_relative 'buildpacks-ci-configuration'

class BuildpacksCIPipelineUpdateCommand
  def run!(concourse_target_name:, pipeline_name:, config_generation_command:, pipeline_variable_filename: "", options:)

    buildpacks_configuration = BuildpacksCIConfiguration.new

    pipeline_prefix = ENV.fetch('PIPELINE_PREFIX', '')

    text_to_include = options[:include]
    text_to_exclude = options[:exclude]
    return if options.has_key?(:include) && !pipeline_name.include?(text_to_include)
    return if options.has_key?(:exclude) && pipeline_name.include?(text_to_exclude)

    puts "   #{pipeline_name} pipeline"

    if !system(config_generation_command, out: File::NULL)
      raise 'Failed to run config generation command'
    end

    secrets_cmd = [
      buildpacks_configuration.concourse_private_filename,
      buildpacks_configuration.deployments_buildpacks_filename,
      buildpacks_configuration.repos_private_keys_filename,
      buildpacks_configuration.cnb_repos_private_keys_filename,
      buildpacks_configuration.git_repos_private_keys_filename,
      buildpacks_configuration.git_repos_private_keys_two_filename,
      buildpacks_configuration.git_repos_private_keys_three_filename,
      buildpacks_configuration.bosh_release_private_keys_filename,
      buildpacks_configuration.bosh_release_private_keys_filename_2,
      buildpacks_configuration.bosh_release_private_keys_filename_lts,
      buildpacks_configuration.dockerhub_cflinuxfs_credentials_filename
    ].map { |name| "lpass show #{name} --notes"}.join(' && ')

    pipeline_specific_config = ""
    pipeline_specific_config ="--load-vars-from=#{pipeline_variable_filename}" unless pipeline_variable_filename.empty?
    fly_cmd = %{bash -c "fly \
      --target=#{concourse_target_name} \
      set-pipeline \
      --pipeline=#{pipeline_prefix}#{pipeline_name} \
      --config=<(#{config_generation_command}) \
      --load-vars-from=<(#{secrets_cmd}) \
      --load-vars-from=public-config.yml \
    #{pipeline_specific_config}
    "}

    system "#{fly_cmd}"
  end
end
