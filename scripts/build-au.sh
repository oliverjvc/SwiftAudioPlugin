#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
swift build -c release --product AudioUnitPlugin
binary_dir="$(swift build -c release --show-bin-path)"
python3 scripts/package-au.py "$binary_dir"
