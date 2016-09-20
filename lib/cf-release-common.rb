#!/usr/bin/env ruby
# encoding: utf-8

def release_names
  Dir['*-buildpack-github-release'].collect { |name| name.gsub(/-buildpack.*/, '') }
end

def find_buildpack_key(blobs, language)
  case language
  when /offline/
    blobs.keys.detect { |key| key =~ /java-buildpack-offline/ }
  when /java/
    blobs.keys.detect { |key| key =~ /java-buildpack-v/ }
  else
    blobs.keys.detect { |key| key =~ /^#{language}-buildpack\// }
  end
end
