#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

require "#{buildpacks_ci_dir}/lib/buildpack-cve-feed"
require "#{buildpacks_ci_dir}/lib/cve-history"
require "#{buildpacks_ci_dir}/lib/notifiers/cve-slack-notifier"

def notify!(language, new_cves, notifiers)
  notifiers.each { |n| n.notify! new_cves, { :category => "buildpack-#{language}", :label => language }, ''}
end

buildpack_cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-buildpack-cves', 'new-buildpack-cve-notifications'))

languages = ['ruby']
languages.each do |language|
  all_cves = BuildpackCVEFeed.run(language)
  past_cves = CVEHistory.read_yaml_cves(buildpack_cves_dir, "#{language}.yml")
  new_cves = all_cves - past_cves

  CVEHistory.write_yaml_cves(all_cves, buildpack_cves_dir, "#{language}.yml") unless new_cves.empty?

  notify!(language, new_cves, [CVESlackNotifier])
end
