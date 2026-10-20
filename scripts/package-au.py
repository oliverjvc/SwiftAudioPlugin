"""Package a native-architecture AUv3 using the macOS Command Line Tools.

The local development signature is ad hoc. Distribution requires an Apple
Developer signing identity and notarization; this script does not publish.
"""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BIN = Path(sys.argv[1]).resolve()
APP = ROOT / "Build" / "Swift Audio.app"
CONTENTS = APP / "Contents"
FRAMEWORK = CONTENTS / "Frameworks" / "AudioUnitPlugin.framework"
VERSION = FRAMEWORK / "Versions" / "A"
EXTENSION = CONTENTS / "PlugIns" / "SwiftAudioPluginExtension.appex"
EXT_CONTENTS = EXTENSION / "Contents"
IDENTIFIER = "com.oliverjvc.SwiftAudioPlugin"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def plist(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as file:
        plistlib.dump(data, file)


def info(name, identifier, kind):
    return dict(CFBundleName=name, CFBundleDisplayName=name, CFBundleExecutable=name,
                CFBundleIdentifier=identifier, CFBundlePackageType=kind,
                CFBundleInfoDictionaryVersion="6.0", CFBundleShortVersionString="1.0",
                CFBundleVersion="1", LSMinimumSystemVersion="13.0")

# Only recreate this script's generated bundle, never the enclosing Build folder.
if APP.exists():
    shutil.rmtree(APP)
for folder in [CONTENTS / "MacOS", VERSION / "Resources", EXT_CONTENTS / "MacOS"]:
    folder.mkdir(parents=True, exist_ok=True)
shutil.copy2(BIN / "libAudioUnitPlugin.dylib", VERSION / "AudioUnitPlugin")
(FRAMEWORK / "Versions" / "Current").symlink_to("A")
(FRAMEWORK / "AudioUnitPlugin").symlink_to("Versions/Current/AudioUnitPlugin")
(FRAMEWORK / "Resources").symlink_to("Versions/Current/Resources")
plist(VERSION / "Resources" / "Info.plist", info("AudioUnitPlugin", IDENTIFIER + ".AudioUnit", "FMWK"))
run("install_name_tool", "-id", "@rpath/AudioUnitPlugin.framework/Versions/A/AudioUnitPlugin", VERSION / "AudioUnitPlugin")

shutil.copy2(ROOT / "AudioPlugin" / "HostApp" / "Info.plist", CONTENTS / "Info.plist")
shutil.copy2(ROOT / "AudioPlugin" / "Extension" / "Info.plist", EXT_CONTENTS / "Info.plist")

sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
arch = os.uname().machine
target = arch + "-apple-macosx13.0"
frameworks = CONTENTS / "Frameworks"
run("xcrun", "clang", "-target", target, "-isysroot", sdk,
    ROOT / "AudioPlugin" / "Extension" / "main.c", "-framework", "Foundation",
    "-F", frameworks, "-framework", "AudioUnitPlugin",
    "-Wl,-rpath,@executable_path/../../../../Frameworks",
    "-o", EXT_CONTENTS / "MacOS" / "SwiftAudioPluginExtension")
run("xcrun", "swiftc", "-target", target, "-sdk", sdk, "-parse-as-library",
    ROOT / "AudioPlugin" / "HostApp" / "AppDelegate.swift",
    "-I", BIN / "Modules", "-I", BIN / "ParameterAtomics.build",
    "-F", frameworks, "-framework", "AudioUnitPlugin",
    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
    "-o", CONTENTS / "MacOS" / "Swift Audio")
run("codesign", "--force", "--sign", "-", FRAMEWORK)
run("codesign", "--force", "--sign", "-", "--entitlements",
    ROOT / "AudioPlugin" / "Extension" / "SwiftAudioPluginExtension.entitlements", EXTENSION)
run("codesign", "--force", "--sign", "-", APP)
run("codesign", "--verify", "--deep", "--strict", APP)
print(f"Built locally signed Audio Unit: {APP}")
