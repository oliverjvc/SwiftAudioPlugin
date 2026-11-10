#!/usr/bin/env python3
"""Package and verify an already-built AU app for a friend's test installation."""
import argparse
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--arch', required=True, choices=['arm64', 'x86_64'])
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
build = root / 'Build'
# Explicit architecture output takes precedence; native default is a fallback.
source = build / args.arch / 'Swift Audio.app'
if not source.is_dir() and args.arch == platform.machine():
    source = build / 'Swift Audio.app'
if not source.is_dir():
    parser.error(f'Build first: bash scripts/build-au.sh --arch {args.arch}')

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

Requirements: macOS 13 or later, and an Audio Unit host such as Logic Pro.

1. Quit Logic Pro and any older copy of Swift Audio.
2. Unzip this file and move the entire Swift Audio.app into Applications. If
   prompted, replace only an older Swift Audio.app. Do not remove or replace any
   other audio plug-ins.
3. Keep exactly one Swift Audio.app on the Mac, inside Applications. Two copies
   of the same plug-in make hosts load the older build. If you think a second
   copy exists, send us its full path instead of moving files yourself. Never
   move anything that is not named Swift Audio.app, and do not open or reorganise
   any Plug-Ins folder; every other plug-in stays exactly where it is.
4. Open Swift Audio once. Its window is a control preview, not a standalone
   audio player.
5. Restart Logic Pro. On an audio track, choose:
   Audio FX > Audio Units > OliverJ > Swift Audio Plugin.
   If it is not visible, wait briefly for macOS to register it, then check this
   plug-in in Logic's Plug-in Manager. Do not delete other plug-ins or move them
   into or out of Logic's Components folder.
6. Keep Swift Audio.app installed. The AUv3 plug-in is contained inside the app.

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

{hardware_note} See QUALITY_REPORT.md for the full validation record and known
limitations.
''', encoding='utf-8')
    shutil.copy2(root / 'QUALITY_REPORT.md', staging)
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', staging, archive)
    run('unzip', '-tq', archive)
    extracted = Path(temporary) / 'verify'
    run('ditto', '-x', '-k', archive, extracted)
    verify(extracted / folder_name / 'Swift Audio.app')
print(archive)
