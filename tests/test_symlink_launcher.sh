#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
symlink_path="/tmp/pipeplay-test-launcher"

rm -f "$symlink_path"
ln -s "$repo_dir/yt" "$symlink_path"

output="$($symlink_path --help 2>&1)"
if [[ "$output" == *"Usage:"* ]]; then
  echo "symlink launcher works"
else
  echo "$output"
  exit 1
fi
