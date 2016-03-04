# encoding: utf-8
require 'json'
require 'octokit'
require 'open-uri'
require 'yaml'

class NewReleasesDetector
  attr_reader :new_releases_dir

  def initialize(new_releases_dir)
    @new_releases_dir = new_releases_dir
  end

  def perform!
    configure_octokit
    tags.each do |current_dependency, get_tags|
      current_tags = get_tags.call

      filename = "#{new_releases_dir}/#{current_dependency}.yaml"
      previous_tags = if File.exist?(filename)
                        YAML.load_file(filename)
                      else
                        []
                      end

      diff_tags = current_tags - previous_tags

      if diff_tags.any?
        File.write(filename, current_tags.to_yaml)
        puts "There are *#{diff_tags.length}* new updates to the *#{current_dependency}* dependency:\n"
        diff_tags.each do |tag|
          puts "- version *#{tag}*\n"
        end

      else
        warn "There are no new updates to the *#{current_dependency}* dependency"
      end
    end
  end

  private

  def configure_octokit
    Octokit.auto_paginate = true
    Octokit.configure do |c|
      c.login    = ENV.fetch('GITHUB_USERNAME')
      c.password = ENV.fetch('GITHUB_PASSWORD')
    end
  end

  def tags
    @get_tags_functions = {
      cfrelease: -> { Octokit.tags('cloudfoundry/cf-release').map(&:name).grep(/^v/) },
      composer:  -> { Octokit.tags('composer/composer').map(&:name) },
      go:        -> { Octokit.tags('golang/go').map(&:name).grep(/^go/) },
      godep:     -> { Octokit.tags('tools/godep').map(&:name).grep(/^v/) },
      httpd:     -> { Octokit.tags('apache/httpd').map(&:name).grep(/^2\./) },
      jruby:     -> { Octokit.tags('jruby/jruby').map(&:name).grep(/^(1|9)\./) },
      maven:     -> { Octokit.tags('apache/maven').map(&:name).grep(/^maven/) },
      nginx:     -> { Octokit.tags('nginx/nginx').map(&:name).grep(/^release/) },
      nodejs:    -> { Octokit.tags('nodejs/node').map(&:name).grep(/^v/) },
      openjdk:   -> { YAML.load(open('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml').read).keys },
      php:       -> { Octokit.tags('php/php-src').map(&:name).grep(/^php/) },
      python:    -> { JSON.parse(open('https://hg.python.org/cpython/json-tags').read)['tags'].map { |t| t['tag'] } },
      ruby:      -> { Octokit.tags('ruby/ruby').map(&:name).grep(/^v/) }
    }
  end
end
