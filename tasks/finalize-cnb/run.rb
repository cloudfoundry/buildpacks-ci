#!/usr/bin/env ruby

require 'fileutils'

artifact_dir = File.join(Dir.pwd, 'release-artifacts')
release_body_file = File.join(artifact_dir, 'body')
buildpack_repo_dir = 'buildpack'


# TODO: remove this cloning when we have a new libcfbuildpack release
`git clone https://github.com/cloudfoundry/libcfbuildpack`
startingDir = Dir.pwd
Dir.chdir('libcfbuildpack/packager')
`go build -o my_packager`
`mv my_packager ../../buildpack`
Dir.chdir(startingDir)

Dir.chdir(buildpack_repo_dir) do
  go_mod_file = File.file?("go.mod")
  if go_mod_file
      # should be replaced when we cut a new libcfbuildpack release with -summary flag
      # `go install github.com/cloudfoundry/libcfbuildpack/packager`
    File.write(release_body_file, `./my_packager -summary`, mode: 'a')
  end
end
