#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_app="$project_dir/Build/Swift Audio.app"
installed_app="$HOME/Applications/Swift Audio.app"
if [[ ! -d "$source_app" ]]; then
    echo 'Build first: bash scripts/build-au.sh' >&2
    exit 1
fi
if [[ -e "$installed_app" ]]; then
    installed_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$installed_app/Contents/Info.plist")"
    if [[ "$installed_id" != 'com.oliverjvc.SwiftAudioPlugin' ]]; then
        echo 'Another app occupies the destination; it was not modified.' >&2
        exit 1
    fi
fi
mkdir -p "$HOME/Applications"
/usr/bin/ditto "$source_app" "$installed_app"
/usr/bin/codesign --verify --deep --strict "$installed_app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$installed_app"
/usr/bin/pluginkit -a "$installed_app/Contents/PlugIns/SwiftAudioPluginExtension.appex"
echo "Installed: $installed_app"
echo 'Validate with: auval -v aufx swft Oliv'
