#!/usr/bin/env bash
# Compute the next sequential `distro-NNNN` release tag from existing
# git tags and emit it on stdout. When run inside GitHub Actions
# (i.e. $GITHUB_OUTPUT is set), also writes `tag=<value>` to the step
# output file so downstream steps can consume it.
set -euo pipefail

git fetch --tags --force >/dev/null

last=$(git tag --list 'distro-*' |
  sed -n 's/^distro-\([0-9]\{4\}\)$/\1/p' |
  sort -n |
  tail -n1)

if [ -z "${last:-}" ]; then
  next=1
else
  next=$((10#$last + 1))
fi

tag=$(printf 'distro-%04d' "$next")
echo "$tag"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "tag=$tag" >>"$GITHUB_OUTPUT"
fi
