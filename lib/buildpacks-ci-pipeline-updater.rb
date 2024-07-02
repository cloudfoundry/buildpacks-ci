# encoding: utf-8

require 'yaml'
require 'optparse'
require_relative 'buildpacks-ci-pipeline-update-command'

class BuildpacksCIPipelineUpdater
  def update_standard_pipelines(options)
    header('For standard pipelines')

    buildpacks_configuration = BuildpacksCIConfiguration.new
    concourse_target_name = buildpacks_configuration.concourse_target_name

    organization = buildpacks_configuration.organization
    run_php_oracle_tests = buildpacks_configuration.run_oracle_php_tests?

    Dir['pipelines/*.{erb,yml}'].each do |filename|
      pipeline_name = File.basename(filename).split('.')[0]

      next if pipeline_name.include?('cflinuxfs4')

      BuildpacksCIPipelineUpdateCommand.new.run!(
        concourse_target_name: concourse_target_name,
        pipeline_name: pipeline_name,
        config_generation_command: "erb organization=#{organization} run_oracle_php_tests=#{run_php_oracle_tests} #{filename}",
        options: options
      )
    end
  end

  def update_buildpack_pipelines(options)
    header('For buildpack pipelines')

    buildpacks_configuration = BuildpacksCIConfiguration.new
    concourse_target_name = buildpacks_configuration.concourse_target_name
    organization = buildpacks_configuration.organization

    Dir['config/buildpack/*.yml'].each do |pipeline_variables_filename|
      next if options.has_key?(:template) && !pipeline_variables_filename.include?(options[:template])

      language = File.basename(pipeline_variables_filename, '.yml')

      BuildpacksCIPipelineUpdateCommand.new.run!(
        concourse_target_name: concourse_target_name,
        pipeline_name: "#{language}-buildpack",
        config_generation_command: "erb language=#{language} organization=#{organization} pipelines/templates/buildpack.yml.erb",
        pipeline_variable_filename: pipeline_variables_filename,
        options: options
      )
    end
  end

  def run!(args)
    options = parse_args(args)

    update_standard_pipelines(options) unless options.has_key?(:template)
    update_buildpack_pipelines(options)

    puts 'Thanks, The Buildpacks Team'
  end

  def parse_args(args)
    # Argument parsing
    specified_options = {}
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ./bin/update-pipelines [options]"

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
    matches = /(lts|edge)\-\d+/.match(deployment_name)
    if matches.nil?
      raise 'Your config/bosh-lite/*.yml files must be named in the following manner: edge-1.yml, edge-2.yml, lts-1.yml, lts-2.yml, etc.'
    end
    matches[1]
  end
end
