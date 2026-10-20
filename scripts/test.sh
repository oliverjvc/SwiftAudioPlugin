#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_flags=(--disable-xctest --enable-swift-testing)

# Some Command Line Tools releases ship Testing as a framework but SwiftPM
# adds its directory as an import/library path instead of a framework path.
if [[ "$(uname -s)" == "Darwin" ]]; then
    developer_dir="$(xcode-select -p)"
    framework_dir="$developer_dir/Library/Developer/Frameworks"
    runtime_dir="$developer_dir/Library/Developer/usr/lib"
    if [[ -d "$framework_dir/Testing.framework" ]]; then
        test_flags+=(
            -Xswiftc -F -Xswiftc "$framework_dir"
            -Xlinker -F -Xlinker "$framework_dir"
            -Xlinker -rpath -Xlinker "$framework_dir"
            -Xlinker -rpath -Xlinker "$runtime_dir"
        )
    fi
fi

exec swift test --package-path "$project_dir" "${test_flags[@]}" "$@"
