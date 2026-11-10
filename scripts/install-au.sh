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
# The Audio Unit database fills in a moment after registration. Hosts that look
# earlier report the component as missing, so wait until it is actually listed.
listed=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if /usr/bin/auval -s aufx 2>/dev/null | grep -q 'aufx swft Oliv'; then
        listed=1
        break
    fi
    sleep 2
done
if [[ "$listed" != 1 ]]; then
    echo 'Still registering. Re-run: auval -s aufx' >&2
fi
# Two bundles with one identifier let a host load the older build, so report
# other copies without touching them.
duplicates=()
for candidate in "/Applications/Swift Audio.app" \
                 "/Library/Audio/Plug-Ins/Components/Swift Audio.app" \
                 "$HOME/Library/Audio/Plug-Ins/Components/Swift Audio.app"; do
    if [[ -e "$candidate" ]]; then duplicates+=("$candidate"); fi
done
if [[ "${#duplicates[@]}" -gt 0 ]]; then
    echo 'Other copies of this bundle exist. A host may load the wrong build.' >&2
    printf '  %s\n' "${duplicates[@]}" >&2
    echo 'Move only those older Swift Audio.app bundles to the Trash; leave every' >&2
    echo 'other audio plug-in where it is.' >&2
fi
echo 'Validate with: auval -v aufx swft Oliv'
