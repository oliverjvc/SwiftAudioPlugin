#!/usr/bin/env python3
"""Package and verify an already-built AU app for a friend's test installation."""
import argparse
import hashlib
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--arch', required=True, choices=['arm64', 'x86_64'])
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
build = root / 'Build'
# Both build commands are supported. Do not silently prefer a stale --arch build
# over a newer native build (or vice versa).
candidates = [build / args.arch / 'Swift Audio.app']
if args.arch == platform.machine():
    candidates.append(build / 'Swift Audio.app')
binary_path = 'Contents/Frameworks/AudioUnitPlugin.framework/Versions/A/AudioUnitPlugin'
candidates = [app for app in candidates if (app / binary_path).is_file()]
if not candidates:
    parser.error(f'Build first: bash scripts/build-au.sh --arch {args.arch}')
source = max(candidates, key=lambda app: (app / binary_path).stat().st_mtime_ns)

def run(*command):
    subprocess.run([str(part) for part in command], check=True)

def verify(app):
    run('codesign', '--verify', '--deep', '--strict', app)
    for binary in [
        'Contents/MacOS/Swift Audio',
        'Contents/Frameworks/AudioUnitPlugin.framework/Versions/A/AudioUnitPlugin',
        'Contents/PlugIns/SwiftAudioPluginExtension.appex/Contents/MacOS/SwiftAudioPluginExtension',
    ]:
        run('lipo', app / binary, '-verify_arch', args.arch)

verify(source)
with (source / 'Contents/Info.plist').open('rb') as file:
    app_info = plistlib.load(file)
label = 'Intel' if args.arch == 'x86_64' else 'arm64'
folder_name = f'SwiftAudioPlugin-quality-{label}'
archive = build / f'{folder_name}.zip'
with tempfile.TemporaryDirectory(prefix='share-au-', dir=build) as temporary:
    staging = Path(temporary) / folder_name
    staging.mkdir()
    run('ditto', source, staging / 'Swift Audio.app')
    machine = 'an Intel Mac' if args.arch == 'x86_64' else 'an Apple Silicon Mac (M1 or later)'
    hardware_note = (
        'This Intel build was tested through Rosetta, not on a physical Intel Mac.'
        if args.arch == 'x86_64'
        else 'This build was validated natively on Apple Silicon, not yet in a '
             'Logic Pro session.'
    )
    (staging / 'README-FIRST.txt').write_text(f'''SWIFT AUDIO — Test Build for {machine}
Version: {app_info['CFBundleShortVersionString']} (build {app_info['CFBundleVersion']})

Requirements: macOS 13 or later, and an Audio Unit host such as Logic Pro.

1. Quit Logic Pro and any older copy of Swift Audio.
2. Unzip this file and move the entire Swift Audio.app into Applications. If
   prompted, replace only an older Swift Audio.app. Do not remove or replace any
   other audio plug-ins.
3. Use one installed Swift Audio.app in Applications. Multiple registered copies
   of the same plug-in can make hosts load a different build. If you think a second
   copy exists, send us its full path instead of moving files yourself. Never
   move anything that is not named Swift Audio.app, and do not open or reorganise
   any Plug-Ins folder; every other plug-in stays exactly where it is.
4. Open Swift Audio once. Its window is a control preview, not a standalone
   audio player.
5. Restart Logic Pro in your usual launch mode. Do not change its Rosetta setting
   just to try this plug-in: that can affect other plug-ins and features.
   Test in a copy of your project or on a new audio track. Click an EMPTY Audio FX
   slot (choosing an occupied slot replaces that track's existing effect), then:
   Audio FX > Audio Units > OliverJ > Swift Audio Plugin.
   If it is not visible, wait briefly for macOS to register it, then check this
   plug-in in Logic's Plug-in Manager. Clear the search and manufacturer filter
   (choose Show All where available) before concluding other plug-ins are missing.
6. Keep Swift Audio.app installed. The AUv3 plug-in is contained inside the app.

If other plug-ins appear missing, stop and record whether they disappeared from
the track's slots, the Audio FX menu, or Plug-in Manager. Include their names,
Logic/macOS versions, Mac type, any error, and whether Logic's Rosetta setting
changed. Do not reset caches or move plug-in files before collecting evidence.
The optional Collect-Diagnostics.command creates a read-only inventory on your
Desktop; it does not install, remove or rescan anything. Review the local paths
and plug-in names in that folder before sending it. If macOS blocks the script,
send the information above instead; no security settings need to be disabled.

This is an ad-hoc signed development build and is not Apple-notarized. If macOS
blocks an app you trust, look for Open Anyway in System Settings > Privacy &
Security. If that option is unavailable or macOS says the app is damaged, send
us the exact error message.

The interface has a single 0–100% Amount knob and bypass. The room reverb
settings are fixed, and a safety limiter protects the output. Logic can automate
Amount and saves it with the project. The Amount control is not yet smoothed, so
rapid changes may click.

For testing, please check mono and stereo tracks, bypass, automation, saving and
reopening a project, and offline bounce. When reporting an issue, include your
Mac model, macOS version, Logic version, and exact steps to reproduce it.

{hardware_note} See README.md for the full validation record and known
limitations.
''', encoding='utf-8')
    shutil.copy2(root / 'README.md', staging)
    (staging / 'BUILD-INFO.txt').write_text(
        f"Version: {app_info['CFBundleShortVersionString']}\n"
        f"Build: {app_info['CFBundleVersion']}\nArchitecture: {args.arch}\n"
        f"Framework SHA256: {hashlib.sha256((source / binary_path).read_bytes()).hexdigest()}\n",
        encoding='utf-8')
    shutil.copy2(root / 'scripts/collect-au-diagnostics.sh', staging / 'Collect-Diagnostics.command')
    (staging / 'Collect-Diagnostics.command').chmod(0o755)
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', staging, archive)
    run('unzip', '-tq', archive)
    extracted = Path(temporary) / 'verify'
    run('ditto', '-x', '-k', archive, extracted)
    verify(extracted / folder_name / 'Swift Audio.app')
print(archive)
