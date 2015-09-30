#!/usr/bin/env bash
set -e

checksum= "`basename pivotal-buildpacks-cached/*_buildpack-cached-v*.zip`.checksum"
echo md5: "`md5sum *_buildpack-cached-v*.zip`" > pivotal-buildpacks-cached/$checksum
echo sha256: "`sha256sum *_buildpack-cached-v*.zip`" >> pivotal-buildpacks-cached/$checksum
cat pivotal-buildpacks-cached/$checksum >> buildpack/RECENT_CHANGES
