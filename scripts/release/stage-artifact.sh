#!/usr/bin/env bash
# Stage the built ISO and its sha256 checksum under ./dist for the
# release publish step. Renames the ISO to include the release tag.
#
# Usage: stage-artifact.sh <tag>
#
# When run inside GitHub Actions, writes `iso=<path>` and
# `sha256=<path>` to $GITHUB_OUTPUT.
set -euo pipefail

tag=${1:?release tag required}

mkdir -p dist
iso=$(find -L result/iso -maxdepth 1 -type f -name '*.iso' | head -n1)
if [ -z "$iso" ]; then
  echo "No ISO found under result/iso" >&2
  exit 1
fi

out="dist/${tag}-x86_64-linux.iso"
cp --reflink=auto "$iso" "$out"
(cd dist && sha256sum "$(basename "$out")" >"$(basename "$out").sha256")

echo "$out"
echo "${out}.sha256"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "iso=$out"
    echo "sha256=${out}.sha256"
  } >>"$GITHUB_OUTPUT"
fi
