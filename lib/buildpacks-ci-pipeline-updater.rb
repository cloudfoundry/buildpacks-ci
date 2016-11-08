# encoding: utf-8

require 'yaml'
require 'optparse'
require_relative 'buildpacks-ci-pipeline-update-command'

class BuildpacksCIPipelineUpdater
  def update_standard_pipelines(target_name:, options:)
    header('For standard pipelines')

    buildpacks_config = BuildpacksCIConfiguration.new

    organization = buildpacks_config.organization
    run_php_oracle_tests = buildpacks_config.run_oracle_php_tests?

    Dir['pipelines/*.yml'].each do |filename|
      pipeline_name = File.basename(filename, '.yml')

      BuildpacksCIPipelineUpdateCommand.new.run!(target_name: target_name,
                   name: pipeline_name,
                   cmd: "erb organization=#{organization} run_oracle_php_tests=#{run_php_oracle_tests} #{filename}",
                   options: options
                  )
    end
  end

  def update_bosh_lite_pipelines(target_name, options)
    header('For bosh-lite pipelines')

    Dir['config/bosh-lite/*.yml'].each do |pipeline_variables_filename|
      next if options.has_key?(:template) && !pipeline_variables_filename.include?(options[:template])

      deployment_name = File.basename(pipeline_variables_filename, '.yml')
      full_deployment_name = YAML.load_file(pipeline_variables_filename)['deployment-name']
      cf_version_type = get_cf_version_from_deployment_name(deployment_name)

      buildpacks_configuration = BuildpacksCIConfiguration.new
      domain_name = buildpacks_configuration.domain_name

      BuildpacksCIPipelineUpdateCommand.new.run!(
        target_name: target_name,
        name: deployment_name,
        cmd: "erb domain_name='#{domain_name}' deployment_name=#{deployment_name} full_deployment_name=#{full_deployment_name} pipelines/templates/bosh-lite-cf-#{cf_version_type}.yml",
        pipeline_variable_filename: pipeline_variables_filename,
        options: options
      )
    end
  end

  def update_buildpack_pipelines(target_name, options)
    header('For buildpack pipelines')

    Dir['config/buildpack/*.yml'].each do |pipeline_variables_filename|
      next if options.has_key?(:template) && !pipeline_variables_filename.include?(options[:template])

      language = File.basename(pipeline_variables_filename, '.yml')

      buildpacks_config = BuildpacksCIConfiguration.new
      organization = buildpacks_config.organization

      BuildpacksCIPipelineUpdateCommand.new.run!(
        target_name: target_name,
        name: "#{language}-buildpack",
        cmd: "erb language=#{language} organization=#{organization} pipelines/templates/buildpack.yml",
        pipeline_variable_filename: pipeline_variables_filename,
        options: options
      )
    end
  end

  def run!(args)
    check_if_lastpass_installed
    options = parse_args(args)

    target_name= ENV['TARGET_NAME'] || "buildpacks"

    if !options.has_key?(:template)
      update_standard_pipelines(target_name: target_name, options: options)
    end
    update_bosh_lite_pipelines(target_name, options)
    update_buildpack_pipelines(target_name, options)

    puts 'Thanks, The Buildpacks Team'
  end

  def parse_args(args)
    # Argument parsing
    specified_options = {}
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ./bin/update-all-the-pipelines [options]"

      opts.on("--include=INCLUDE", "-iINCLUDE", "Update pipelines if their names include this string") do |include_string|
        specified_options[:include] = include_string
      end

      opts.on("--exclude=EXCLUDE", "-eEXCLUDE", "Skip pipelines if their names include this string") do |exclude_string|
        specified_options[:exclude] = exclude_string
      end

      opts.on("--template=TEMPLATE", "-tTEMPLATE", "Only update pipelines from the specified template") do |template_string|
        specified_options[:template] = template_string
      end
    end
    opt_parser.parse!(args)
    specified_options
  end

  private

  def header(msg)
    print '*' * 10
    puts " #{msg}"
  end

  def get_cf_version_from_deployment_name(deployment_name)
    matches = /(lts|edge)\-\d+(\-azure)?/.match(deployment_name)
    if matches.nil?
      puts 'Your config/bosh-lite/*.yml files must be named in the following manner: edge-1.yml, edge-2.yml, lts-1.yml, lts-2.yml, etc.'
      exit 1
    end
    matches[1]
  end

  def check_if_lastpass_installed
    raise '`brew install lastpass-cli` is required' if `which lpass` == ''
  end

  def credential_filenames
    {
      lpass_concourse_private:  ENV['LPASS_CONCOURSE_PRIVATE_FILE'] || 'Shared-Buildpacks/concourse-private.yml',
      lpass_deployments_buildpacks: ENV['LPASS_DEPLOYMENTS_BUILDPACKS_FILE'] || 'Shared-Buildpacks/deployments-buildpacks.yml',
      lpass_repos_private_keys: ENV['LPASS_REPOS_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-repos-private-keys.yml',
      lpass_bosh_release_private_keys: ENV['LPASS_BOSH_RELEASE_PRIVATE_KEYS_FILE'] || 'Shared-Buildpacks/buildpack-bosh-release-repos-private-keys.yml'
    }
  end
end
