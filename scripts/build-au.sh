#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
architecture="$(uname -m)"
output_dir="$project_dir/Build"
if [[ "$#" -gt 0 ]]; then
    if [[ "$#" != 2 || "$1" != '--arch' ]]; then
        echo 'Usage: bash scripts/build-au.sh [--arch arm64|x86_64]' >&2
        exit 1
    fi
    architecture="$2"
    output_dir="$project_dir/Build/$architecture"
fi
case "$architecture" in
    arm64|x86_64) ;;
    *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;;
esac
swift build -c release --arch "$architecture" --product AudioUnitPlugin
binary_dir="$(swift build -c release --arch "$architecture" --show-bin-path)"
python3 scripts/package-au.py "$binary_dir" --arch "$architecture" --output-dir "$output_dir"
