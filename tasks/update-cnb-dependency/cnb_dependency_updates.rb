#!/usr/bin/env ruby
class CNBDependencyUpdates
  class << self
    # Replace all Time objects with DateTime (needed to use toml library)
    # Will not replace Time objects if they occur as the key in a map.
    def replace_date_with_time(obj, parent_obj = nil, accessor = nil)
      if obj.class == Time
        converted_time = time_to_datetime(obj)
        if parent_obj == nil
          return converted_time
        end
        parent_obj[accessor] = converted_time

      elsif obj.class == Array
        obj.each_with_index  do |val,index|
          obj[index] = replace_date_with_time(val,obj,index)
        end
        return obj
      elsif obj.class == Hash
        obj.each do |key, value|
          obj[key] = replace_date_with_time(value, obj, key)
        end
        return obj
      else obj
      end
    end

    # TODO: Move to buildpack_toml class
    def update_dependency_deprecation_dates(deprecation_date, deprecation_link, version_line, dependency_name, deprecation_match, deprecation_dates)
        dependency_deprecation_date = {
            'version_line' => version_line.downcase,
            'name'         => dependency_name,
            'date'         => DateTime.parse(deprecation_date),
            'link'         => deprecation_link,
        }

        unless deprecation_match.nil? or deprecation_match.empty? or deprecation_match.downcase == 'null'
          dependency_deprecation_date['match'] = deprecation_match
        end

        deprecation_dates.reject{ |d| d['version_line'] == version_line.downcase and d['name'] == dependency_name}
                          .push(dependency_deprecation_date)
                          .sort_by{ |d| [d['name'], d['version_line'] ]}
    end

    def commit_message(dependency_name, resource_version, rebuilt, removed, total_stacks)
      commit_message = "Add #{dependency_name} #{resource_version}"
      commit_message = "Rebuild #{dependency_name} #{resource_version}" if rebuilt
      if removed.length > 0
        commit_message = "#{commit_message}, remove #{dependency_name} #{removed.join(', ')}"
      end
      commit_message + "\n\nfor stack(s) #{total_stacks.join(', ')}"
    end

    # TODO: Move to buildpack_toml class
    def update_default_deps?(buildpack_toml, removal_strategy)
      if buildpack_toml.dig('metadata', 'default_versions').nil?
        return false
      end
      removal_strategy == "remove_all"
    end

    # TODO: Separate 2 purposes: dep updates, and commit message
    def update_stacks_list(stack, dependency_name, stacks_so_far, stacks_map)
      if (stack == 'any-stack') || (stack == 'cflinuxfs3' && dependency_name == 'dep') # TODO Figure out if temporary
        stacks_so_far += stacks_map.values
        v3_stacks = stacks_map.values
      else
        stacks_so_far += [stacks_map[stack]]
        v3_stacks = [stacks_map[stack]]
        if stack == 'bionic'
          if dependency_name == "go" or dependency_name == "dep"
            v3_stacks += [stacks_map['tiny']]
            stacks_so_far |= [stacks_map['tiny']]
          end
        end
      end
      [v3_stacks, stacks_so_far]
    end

    private
    def time_to_datetime(time)
      DateTime.parse(time.to_s)
    end
  end
end
