require 'yaml'
require 'octokit'

class ReleaseGithubIssueGenerator
  def initialize(octokit_client)
    @client = octokit_client
  end

  def run(buildpack_name, previous_buildpack_version, old_manifest, new_manifest)
    @previous_buildpack_version = previous_buildpack_version
    @old_manifest = old_manifest
    @new_manifest = new_manifest
    issue_name = "**Release:** #{buildpack_name}-buildpack #{new_release_version}"

    issue_description = "\n**Dependency Changes:**\n\n"
    issue_description += generate_dependency_changes
    issue_description += "\n**New Commits on Develop**:\n\n"
    issue_description += get_git_log
    issue_description += "\nRefer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).\n"

    create_issues(issue_name, issue_description, buildpack_name)
  end

  def create_issues(title, description, buildpack)
    issue = @client.create_issue("cloudfoundry/#{buildpack}-buildpack", title, description)
    @client.create_project_card(13320470, content_id: issue.id, content_type: 'Issue', mediaType: {
    previews: [
      'inertia'
    ]
  })
  end

  def new_release_version
    @previous_buildpack_version.split('.').tap do |arr|
      arr[-1].succ!
    end.join('.')
  end

  def get_added_versions(new_deps, old_deps, name)
    ((new_deps[name] || []) - (old_deps[name] || [])).collect{|i| i.to_s}.uniq.sort
  end

  def get_removed_versions(new_deps, old_deps, name)
    ((old_deps[name] || []) - (new_deps[name] || [])).collect{|i| i.to_s}.uniq.sort
  end

  def create_dependency_version_mapping(dep_array)
    dep_array.each_with_object({}) do |dep, h|
      if h.key?(dep['name'])
        h[dep['name']].push(dep['version'])
      else
        h[dep['name']] = [dep['version']]
      end
    end
  end

  def generate_dependency_changes
    old_dependencies = YAML.safe_load(@old_manifest, permitted_classes: [Date])['dependencies']
    new_dependencies = YAML.safe_load(@new_manifest, permitted_classes: [Date])['dependencies']
    old_deps_map = create_dependency_version_mapping(old_dependencies)
    new_deps_map = create_dependency_version_mapping(new_dependencies)

    description = ''

    new_deps_map.each_key do |name|
      added_versions = get_added_versions(new_deps_map, old_deps_map, name)
      removed_versions = get_removed_versions(new_deps_map, old_deps_map, name)
      if !added_versions.empty? && !removed_versions.empty?
        description += "\n#{name}:\n"
        description += "- #{removed_versions.join("\n- ")}\n"
        description += "+ #{added_versions.join("\n+ ")}\n"
      end
    end
    description += "\n"
    new_deps_map.each_key do |name|
      added_versions = get_added_versions(new_deps_map, old_deps_map, name)
      removed_versions = get_removed_versions(new_deps_map, old_deps_map, name)
      if !added_versions.empty? && removed_versions.empty?
        description += "+ Added #{name} at version(s): #{added_versions.join(', ')}\n"
      end
    end
    old_deps_map.each_key do |name|
      added_versions = get_added_versions(new_deps_map, old_deps_map, name)
      removed_versions = get_removed_versions(new_deps_map, old_deps_map, name)
      if added_versions.empty? && !removed_versions.empty?
        description += "- Removed #{name} at version(s): #{removed_versions.join(', ')}\n"
      end
    end

    if @buildpack_name == 'r'
      shared_r_versions = old_deps_map['r'] & new_deps_map['r']

      shared_r_versions.each do |version|
        old_sub_deps = create_dependency_version_mapping(old_dependencies.find { |dep| dep['version'] == version }.fetch('dependencies', []))
        new_sub_deps = create_dependency_version_mapping(new_dependencies.find { |dep| dep['version'] == version }.fetch('dependencies', []))

        if new_sub_deps != old_sub_deps
          description += "r #{version}:\n"
          new_sub_deps.each_key do |name|
            added_versions = get_added_versions(new_sub_deps, old_sub_deps, name)
            removed_versions = get_removed_versions(new_sub_deps, old_sub_deps, name)
            if !added_versions.empty? && !removed_versions.empty?
              description += "  #{name}:\n"
              description += "-   #{removed_versions.join("\n-   ")}\n"
              description += "+   #{added_versions.join("\n+   ")}\n"
            end
          end

        end
      end
    end

    if description == "\n"
      description = "\nNo dependency changes\n"
    end

    "```diff#{description}```\n"
  end

  def get_git_log
    description = ''
    description += `git log origin/master..origin/develop  --pretty=oneline --abbrev-commit`

    "#{description}"
  end
end
