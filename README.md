# Swift Audio Plugin

A focused room reverb Audio Unit for Logic Pro. Its wood-inspired editor has one
Amount knob (0–100%) and bypass. Room character is fixed to a tuned classical
room; a fixed peak limiter protects the output. The Amount control is host
automatable and existing project state continues to load.

## Build and test

Requires macOS 13+, Apple Command Line Tools or Xcode, and Swift 6+ for tests.
The CLT testing runtime can require macOS 14+ even though the plugin targets 13.

```bash
git clone https://github.com/oliverjvc/SwiftAudioPlugin.git
cd SwiftAudioPlugin
swift build
bash scripts/test.sh
```

`test.sh` runs `swift test` with the framework/runtime search paths needed by
Command Line Tools. It forwards arguments, for example `--filter AudioUnitTests`.
With a full Xcode toolchain that supplies those paths, `swift test` can be used
without the wrapper. Open `Package.swift` directly to edit in Xcode.

## Install the Audio Unit for Logic Pro

```bash
bash scripts/build-au.sh
bash scripts/install-au.sh
auval -v aufx swft Oliv -strict
auval -v aufx swft Oliv -oop -strict
```

The build script creates `Build/Swift Audio.app`, containing the AUv3 extension
and its embedded framework. It uses Command Line Tools; a full Xcode installation
is not needed. The installer copies it to `~/Applications/Swift Audio.app` and
registers the extension. Initial macOS Audio Unit discovery can take a minute;
the installer waits until the component is listed before it reports success. If a
host still says the plugin is missing, check `auval -s aufx` and retry once
**OliverJ: Swift Audio Plugin** appears.

Restart Logic Pro after installation. On an audio channel, choose an **Audio FX**
slot, then **Audio Units → OliverJ → Swift Audio Plugin**. Mono and stereo channels
are supported. If necessary, rescan this plugin in Logic's Plug-in Manager.
Keep the containing app installed: this is an AUv3 extension, not a `.component`
file to copy into `Library/Audio/Plug-Ins/Components`. Installing it does not
require deleting or replacing any other Audio Units.

Keep exactly one `Swift Audio.app` on the Mac. Two bundles sharing the identifier
let a host load the older build, so the installer lists any other copy it finds in
`/Applications` or in a Components folder and tells you to move only that older
`Swift Audio.app` away. It never deletes anything itself; every other audio
plug-in stays where it is.

Opening **Swift Audio.app** displays the plugin's controls for inspection. That
window does not capture or play audio; use the plugin on a track in Logic for
sound. The older `swift run SwiftAudioPlugin` interface remains a separate DSP/UI
demo and is not the installed AU editor.

By default the build contains the architecture of the Mac used to build it
(arm64 on Apple Silicon, x86_64 on Intel). An explicit architecture can also be
cross-compiled with the macOS SDK:

```bash
bash scripts/build-au.sh --arch x86_64
# Result: Build/x86_64/Swift Audio.app
bash scripts/build-au.sh --arch arm64
# Result: Build/arm64/Swift Audio.app
```

Explicit architecture builds use separate output directories. The packager
checks the architecture of the framework, extension and host executable before
signing. On Apple Silicon, SwiftPM may try to load Intel tests into its ARM test
helper. Run the whole test command under Rosetta instead:
`arch -x86_64 /bin/bash scripts/test.sh --arch x86_64`.

Run Logic with the matching architecture. Builds are signed ad hoc for
local development; they are not notarized distribution builds. Sharing binaries
can require recipient approval in macOS Privacy & Security settings. For normal
distribution, use Developer ID signing and notarization.

## Audio Unit controls

- **Amount:** 0–100% level of a fixed, stereo room reverb.
- **Bypass:** temporarily returns the unprocessed signal.

Turn the knob vertically to adjust the amount. Logic automation and project save
and restore work through the host's 0–100% Amount parameter. The sole factory
preset is Classical Room.

Signal flow:

```
Input → Room Reverb (fixed room, pre-delay and width) → Output → Safety Limiter
```

The AU negotiates matching mono or stereo planar Float32 input/output, from
8 kHz through 192 kHz. Delay/reverb storage is recreated at resource allocation
for the negotiated sample rate. Render buffers are allocated ahead of time.
The master Amount is a normalized 0–100% AU parameter. UI/host values cross to the
render thread through lock-free scalar atomics; the render thread owns the DSP
engine. Scheduled changes and ramps are processed at sample offsets. This Swift
implementation has not been formally certified for hard real-time safety.

## Source layout

- `Sources/DSP/`: processing algorithms; the AU currently uses the fixed room reverb.
- `Sources/Plugin/`: AU lifecycle, parameter/state handling and the AU editor.
- `Sources/ParameterAtomics/`: C11 atomic storage shared by control/render threads.
- `Sources/UI/`, `Sources/App/`: original standalone UI demo.
- `AudioPlugin/`: host/extension entry points, metadata and extension entitlements.
- `scripts/`: tests, local packaging and installation.
- `Tests/DSPTests/`, `Tests/AudioUnitTests/`: DSP and AU integration tests.

The AU tests cover state serialization, mono/stereo gain and bypass, variable
block sizes, scheduled changes, ramps crossing blocks, null output buffers,
format rejection, resource reallocation, render blocks cached before
allocation, and a reported tail time that matches the measured reverb decay.
Apple `auval` separately checks the installed component.

## Limitations

- Logic Pro session playback and project reopening require testing in Logic itself;
  a successful `auval` run does not replace that host-specific check.
- No VST3 or AAX wrapper. The AU packaging/editor are macOS-only.
- The standalone demo does not implement a microphone/audio-device engine.
- There is no room-size, delay, EQ or compressor control on the plugin surface.
- The limiter is sample-peak, not true-peak; Amount changes are not yet smoothed.
- See [quality review](QUALITY_REPORT.md) for testing and distribution limitations.

MIT License. See `LICENSE`.

## Validation record

Validated locally on 2026-11-06 with macOS 26.3, Apple Silicon and Swift 6.3.3:

- `swift build`: passed.
- `bash scripts/test.sh`: 51 tests passed in four suites, and the same 51 passed
  for x86_64 under Rosetta.
- `auval -v aufx swft Oliv -strict`: passed without warnings.
- `auval -v aufx swft Oliv -oop -strict`: passed without warnings.
- The AU registry and both `Library/Audio/Plug-Ins/Components` folders were
  compared before and after installing: unchanged apart from this plugin.
  `auval -s aufx` still lists all 22 Apple effect units alongside ours.
- Updated Amount and bypass controls are in the custom AU editor; plugin layout
  has been built for arm64 and x86_64.
- Logic Pro playback/project-reopen testing was not performed.

Local build/test/validation logs are generated in the ignored `Build/` folder.

Intel build validation on 2026-10-20: the host, extension and framework were
cross-compiled for x86_64, their signatures and extracted ZIP bundle verified,
and all 49 tests passed with the Intel test helper under Rosetta. The Intel
build has not yet been checked with `auval`, on physical Intel hardware or in
a Logic Pro session. Shareable test packages remain in the ignored `Build/`
folder.

## Share a test build

After building the requested architecture:

```bash
python3 scripts/share-au.py --arch arm64
python3 scripts/share-au.py --arch x86_64
```

Produces `Build/SwiftAudioPlugin-quality-arm64.zip` or
`Build/SwiftAudioPlugin-quality-Intel.zip` with the app, Serbian installation
English installation instructions and the quality review. Signatures and architecture are checked
again after extracting the ZIP. These remain development builds.
