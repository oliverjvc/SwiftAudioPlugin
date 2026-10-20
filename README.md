# Swift Audio Plugin

A Swift audio channel strip for macOS: five-band EQ, compressor, stereo delay,
algorithmic reverb and limiter. The Audio Unit v3 build is intended for Logic Pro
and includes a custom SwiftUI editor, 50 automatable parameters, four factory
presets and project/preset state restoration. The editor includes stereo peak
meters, gain-reduction readouts, A/B comparison and direct numeric entry.

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
registers the extension. Initial macOS Audio Unit discovery can take a minute.
If the first validation says the component is missing, check `auval -a` and retry
once **OliverJ: Swift Audio Plugin** appears.

Restart Logic Pro after installation. On an audio channel, choose an **Audio FX**
slot, then **Audio Units → OliverJ → Swift Audio Plugin**. Mono and stereo channels
are supported. If necessary, rescan this plugin in Logic's Plug-in Manager.
Keep the containing app installed: this is an AUv3 extension, not a `.component`
file to copy into `Library/Audio/Plug-Ins/Components`.

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

- **Main:** input/output gain and bypass.
- **Equalizer:** five peak bands, each with frequency, gain, Q and enable controls.
- **Compressor:** threshold, ratio, attack, release, makeup, knee and enable.
- **Delay:** separate left/right times, feedback, wet/dry, ping-pong, filters and enable.
- **Reverb:** room size, damping, wet/dry, stereo width, pre-delay and enable.
- **Limiter:** ceiling, release and enable.

Use the Factory presets menu to load a starting point. A/B compares all current
parameter values; Copy A → B (or B → A) initializes the other slot. Comparison
slots last while the editor is open. Type a number and press Return (or leave the
field) to commit; right-click a numeric control to reset its default. Input/output
meters show dBFS and the COMP/LIMIT readouts show gain reduction in dB.

Factory presets: Default, Warm Vocal, Punchy Drums and Ambient Pad. Logic can
save the exposed parameters in projects and Audio Unit presets. The AU delay
uses milliseconds; the DSP library's optional tempo-sync controls and EQ filter
types are not exposed in this version's AU editor.

Signal flow:

```
Input → Input Gain → EQ → Compressor → Delay → Reverb → Output Gain → Limiter → Output
```

The AU negotiates matching mono or stereo planar Float32 input/output, from
8 kHz through 192 kHz. Delay/reverb storage is recreated at resource allocation
for the negotiated sample rate. Render buffers are allocated ahead of time.
UI/host values cross to the render thread through lock-free scalar atomics; the
render thread owns the DSP engine. Scheduled changes and ramps are processed at
sample offsets. This Swift implementation has not been formally certified for
hard real-time safety.

## Source layout

- `Sources/DSP/`: processing algorithms and standalone preset serialization.
- `Sources/Plugin/`: AU lifecycle, parameter/state handling and the AU editor.
- `Sources/ParameterAtomics/`: C11 atomic storage shared by control/render threads.
- `Sources/UI/`, `Sources/App/`: original standalone UI demo.
- `AudioPlugin/`: host/extension entry points, metadata and extension entitlements.
- `scripts/`: tests, local packaging and installation.
- `Tests/DSPTests/`, `Tests/AudioUnitTests/`: DSP and AU integration tests.

The AU tests cover state serialization, mono/stereo gain and bypass, variable
block sizes, scheduled changes, ramps crossing blocks, null output buffers,
format rejection, resource reallocation and render blocks cached before
allocation. Apple `auval` separately checks the installed component.

## Limitations

- Logic Pro session playback and project reopening require testing in Logic itself;
  a successful `auval` run does not replace that host-specific check.
- No VST3 or AAX wrapper. The AU packaging/editor are macOS-only.
- The standalone demo does not implement a microphone/audio-device engine.
- The AU has peak/GR meters but no spectrum analyzer or graphical EQ curve.
- The limiter is sample-peak, not true-peak. Abrupt parameter/preset/bypass changes
  are not yet smoothed. See [quality review](QUALITY_REPORT.md) for remaining gaps.

MIT License. See `LICENSE`.

## Validation record

Validated locally on 2026-10-20 with macOS 26.3, Apple Silicon and Swift 6.3.3:

- `swift build`: passed.
- `bash scripts/test.sh`: 49 tests passed in four suites.
- `auval -v aufx swft Oliv -strict`: passed without warnings.
- `auval -v aufx swft Oliv -oop -strict`: passed without warnings.
- Installed bundle code signatures verified; preview controls visually checked,
  including a compressor parameter change and restoration.
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
instructions and the quality review. Signatures and architecture are checked
again after extracting the ZIP. These remain development builds.
