#!/usr/bin/env bash
# Build the installer ISO via the flake's `iso.x86_64-linux.installer`
# output. Leaves the build result symlink at ./result.
set -euo pipefail

nix build .#iso.x86_64-linux.installer --print-build-logs
