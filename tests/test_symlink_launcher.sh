#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"

for cmd in pipeplay pplay ppy; do
  output="$($repo_dir/$cmd --help 2>&1)"
  if [[ "$output" == *"Usage:"* ]]; then
    echo "$cmd works"
  else
    echo "$cmd failed"
    echo "$output"
    exit 1
  fi
done
