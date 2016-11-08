class BuildpacksCIPipelineUpdateCommand
  def run!(target_name:, name:, cmd:, pipeline_variable_filename: "", options:)
    pipeline_prefix = ENV['PIPELINE_PREFIX'] || ''

    text_to_include = options[:include]
    text_to_exclude = options[:exclude]
    return if options.has_key?(:include) && !name.include?(text_to_include)
    return if options.has_key?(:exclude) && name.include?(text_to_exclude)

    puts "   #{name} pipeline"

    pipeline_specific_config = ""
    pipeline_specific_config ="--load-vars-from=#{pipeline_variable_filename}" unless pipeline_variable_filename.empty?
    fly_cmd = %{bash -c "fly \
      --target=#{target_name} \
      set-pipeline \
      --pipeline=#{pipeline_prefix}#{name} \
      --config=<(#{cmd}) \
      --load-vars-from=<(lpass show #{credential_filenames[:lpass_concourse_private]} --notes && lpass show #{credential_filenames[:lpass_deployments_buildpacks]} --notes && lpass show #{credential_filenames[:lpass_repos_private_keys]} --notes && lpass show #{credential_filenames[:lpass_bosh_release_private_keys]}) \
      --load-vars-from=public-config.yml \
    #{pipeline_specific_config}
    "}

    system "#{fly_cmd}"
  end

  private

  def credential_filenames
    {
      lpass_concourse_private:  ENV['LPASS_CONCOURSE_PRIVATE_FILE'] || 'Shared-Buildpacks/concourse-private.yml',
      lpass_deployments_buildpacks: ENV['LPASS_DEPLOYMENTS_BUILDPACKS_FILE'] || 'Shared-Buildpacks/deployments-buildpacks.yml',
      lpass_repos_private_keys: ENV['LPASS_REPOS_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-repos-private-keys.yml',
      lpass_bosh_release_private_keys: ENV['LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-bosh-release-repos-private-keys.yml'
    }
  end
end
