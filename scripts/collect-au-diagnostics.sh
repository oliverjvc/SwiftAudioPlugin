#!/bin/bash
# Read-only inventory. Writes only a new report directory; never installs,
# unregisters, disables, rescans, or removes a plug-in or cache.
set -eu
umask 077
if [[ $# -gt 1 ]]; then
    echo 'Usage: bash collect-au-diagnostics.sh [new-report-directory]' >&2
    exit 1
fi
if [[ $# -eq 1 ]]; then
    report_dir="$1"
    mkdir -m 700 "$report_dir" # Refuse to overwrite an existing report.
else
    report_dir="$(mktemp -d "$HOME/Desktop/Swift-Audio-diagnostics.XXXXXX")"
fi
{
    /usr/bin/sw_vers
    /usr/bin/uname -m
    /usr/sbin/sysctl -n hw.model
    for app in '/Applications/Logic Pro.app' "$HOME/Applications/Logic Pro.app"; do
        if [[ -f "$app/Contents/Info.plist" ]]; then
            echo "Logic: $app"
            /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist"
        fi
    done
    echo 'Report does not determine Logic launch mode, menu filters, or project slots.'
} > "$report_dir/system.txt" 2>&1
# List registrations only; -a does not validate or reset units.
/usr/bin/auval -a > "$report_dir/audio-units.txt" 2>&1 || true
/usr/bin/pluginkit -m -A -D -v -p com.apple.AudioUnit-UI > "$report_dir/auv3-registrations.txt" 2>&1 || true
{
    for folder in '/Library/Audio/Plug-Ins/Components' "$HOME/Library/Audio/Plug-Ins/Components"; do
        echo "Folder: $folder"
        if [[ -d "$folder" ]]; then
            /usr/bin/find "$folder" -mindepth 1 -maxdepth 1 -print | /usr/bin/sort
        else
            echo '(folder absent)'
        fi
    done
} > "$report_dir/components.txt" 2>&1
{
    for app in '/Applications/Swift Audio.app' "$HOME/Applications/Swift Audio.app"; do
        if [[ -d "$app" ]]; then
            echo "App: $app"
            /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist" || true
            /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist" || true
            /usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist" || true
            binary="$app/Contents/Frameworks/AudioUnitPlugin.framework/Versions/A/AudioUnitPlugin"
            /usr/bin/shasum -a 256 "$binary" || true
            /usr/bin/file "$binary" || true
            /usr/bin/codesign --verify --deep --strict "$app" || true
        fi
    done
} > "$report_dir/swift-audio.txt" 2>&1
{
    for folder in "$HOME/Library/Logs/DiagnosticReports" '/Library/Logs/DiagnosticReports'; do
        if [[ -d "$folder" ]]; then
            /usr/bin/find "$folder" -maxdepth 1 -type f \( -iname '*logic*' -o -iname '*auhosting*' -o -iname '*audiocomponent*' -o -iname '*auval*' -o -iname '*swiftaudio*' -o -iname '*swift audio*' \) -print
        fi
    done
} > "$report_dir/crash-report-paths.txt" 2>&1
echo "Saved read-only inventory: $report_dir"
echo 'Includes local paths and installed plug-in names; review before sharing.'
