#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

# Check both the cached and uncached artifacts to make sure the executables
# have been compiled correctly

export supply_binary_type finalize_binary_type

supply_binary_type=$(unzip -q pivotal-buildpack -d uncached && file uncached/bin/supply)
finalize_binary_type=$(file uncached/bin/finalize)

if [[ $supply_binary_type != *"ELF 64-bit LSB executable, x86-64, version 1 (SYSV)"* &&
$finalize_binary_type != *"ELF 64-bit LSB executable, x86-64, version 1 (SYSV)"* ]]; then
  echo "uncached buildpack: supply or finalize scripts are not compiled correctly"
  exit 1
fi

supply_binary_type=$(unzip -q pivotal-buildpack-cached -d cached && file cached/bin/supply)
finalize_binary_type=$(file cached/bin/finalize)
if [[ $supply_binary_type != *"ELF 64-bit LSB executable, x86-64, version 1 (SYSV)"* &&
$finalize_binary_type != *"ELF 64-bit LSB executable, x86-64, version 1 (SYSV)"* ]]; then
  echo "cached buildpack: supply or finalize scripts are not compiled correctly"
  exit 1
fi

rm -rf cached uncached
exit 0
