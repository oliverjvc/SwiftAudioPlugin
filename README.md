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

Restart Logic Pro after installation. On a new audio channel or a copy of your
project, choose an **empty Audio FX**
slot, then **Audio Units → OliverJ → Swift Audio Plugin**. Mono and stereo channels
are supported. If necessary, rescan this plugin in Logic's Plug-in Manager.
Keep the containing app installed: this is an AUv3 extension, not a `.component`
file to copy into `Library/Audio/Plug-Ins/Components`. Installing it does not
require deleting or replacing any other Audio Units.

Keep exactly one `Swift Audio.app` on the Mac. Two bundles sharing the identifier
can make a host load a different build. The installer reports candidate paths.
Compare the bundle identifiers and versions before choosing which copy to keep.

Opening **Swift Audio.app** displays the plugin's controls for inspection. That
window does not capture or play audio; use the plugin on a track in Logic for
sound. It hosts the same editor the AU shows inside Logic.

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

Keep Logic's usual native/Rosetta launch mode while testing; changing it can affect
other plug-ins and features. Report a compatibility error before changing that
setting. Builds are signed ad hoc for
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
- The `Swift Audio.app` preview window opens no audio device; it only displays
  the AU editor.
- There is no room-size, delay, EQ or compressor control on the plugin surface.
- The limiter is sample-peak, not true-peak; Amount changes are not yet smoothed.

MIT License. See `LICENSE`.

## Validation record

Validated locally on 2026-11-08 with macOS 26.3, Apple Silicon and Swift 6.3.3:

- `swift build`: passed.
- `bash scripts/test.sh`: 51 tests passed in four suites, and the same 51 passed
  for x86_64 under Rosetta.
- `auval -v aufx swft Oliv -strict`: passed without warnings.
- `auval -v aufx swft Oliv -oop -strict`: passed without warnings.
- The AU registry (all six Audio Unit types), both
  `Library/Audio/Plug-Ins/Components` folders and the plug-in manager list were
  compared before and after installing: the only differences were this plugin's
  own registration id and timestamp. `auval -s aufx` lists all 23 Apple effect
  units alongside ours.
- The AU editor renders identically before and after the code removal: the
  offscreen PNGs are byte-for-byte the same file.
- Amount and bypass controls are in the custom AU editor; plugin layout has been
  built for arm64 and x86_64.
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
`Build/SwiftAudioPlugin-quality-Intel.zip` with the app, English installation
instructions and this README. Signatures and architecture are checked
again after extracting the ZIP. These remain development builds.


## Troubleshooting missing Logic Pro plug-ins on Apple Silicon

1. **Capture the current state before changing anything.** In Logic Pro, open
   **Settings → Plug-in Manager**, clear the search, and select **Show All**
   where available. Record an affected plug-in name and its compatibility status.
   Check whether it is missing from the manager, the Audio FX menu, or only an
   occupied slot in one project.
2. **Check Logic’s launch mode.** Quit Logic Pro, select its app in Finder,
   open **Get Info** (Command-I), and note whether **Open using Rosetta** is
   checked, if the option is available. Keep the mode that previously worked
   with your plug-ins. If you changed the setting for Swift Audio, capture a
   report first, then restore the previous setting and reopen Logic in an empty
   project. Some ARA integrations require Logic to run under Rosetta. Rosetta
   being installed and Logic itself running under Rosetta are separate settings.
   See [Apple’s compatibility guide](https://support.apple.com/en-gb/102082).
3. **Preserve the evidence before a rescan.** Record macOS and Logic versions,
   startup or validation errors, and the result after restoring the previous
   mode. Start with a targeted rescan if one unit failed validation.

### Standalone diagnostic ZIP

Download **SwiftAudioPlugin-diagnostics.zip** from the
[separate diagnostics branch](https://github.com/oliverjvc/SwiftAudioPlugin/tree/diagnostics/diagnostics).
Extract it and open `Collect-Diagnostics.command`. It records installed
components, AU registrations, Swift Audio versions and hashes, and relevant
crash-report paths in a new Desktop folder. Review the report before sharing
it because it contains local paths and plug-in names. The archive contains
the collector and its instructions. Run it on the affected Mac before
reinstalling anything or resetting caches.

### Investigation record — 2026-11-09

### Finding and limits

No deletion or registry displacement of another vendor's plug-in has been
reproduced. This is not a finding that the reported incident did not happen.
The affected computer's plug-in names, Logic version, launch mode, Plug-in
Manager state and crash logs have not been supplied. This development Mac has
no Logic Pro installation and no third-party AUv2 components. Consequently,
the exact cause of the incident remains unconfirmed.

The previous code-only review was too narrow: a plug-in need not delete files
for other effects to disappear from a menu or project. In particular, the
archived Apple Silicon instructions explicitly required native Logic without
Rosetta, and all the old hand-outs omitted the word **empty** before Audio FX
slot. Both instructions can lead to visible changes outside our plug-in.

### Versions actually examined

- Archived `Build/outdated/SwiftAudioPlugin-test-{arm64,Intel}.zip`: the included
  instructions identify commit `7afd36a`; both binaries were loaded directly in
  separate test processes, without installing/registering the old bundles.
- `e1c4618`: previous channel-strip source, installer, packaging and instructions;
  tested from a separate source snapshot under `Build/audit-2026-11-09/`.
- `f52b930`, `1f14188`, `65fe6aa`: Qoder's changes and audit claims. The working
  tree was clean at the beginning of this review. Its two distribution ZIPs
  matched the corresponding local framework SHA256s; the installed ARM build
  also matched. Copies were retained in the audit directory before repackaging.

All these versions share the app and extension bundle identifiers and
`aufx / swft / Oliv` component identity. That deliberately replaces **our own**
earlier channel strip with the new reverb. It does not establish a collision
with another manufacturer's unit. No such collision was found locally.

### Code and binary findings

- Neither app runtime nor AU runtime calls file deletion, shell commands, Logic
  preferences editing, cache resets, or third-party unregistration. The AU
  extension has the app-sandbox entitlement without broad file access.
- The installer copies one bundle into `~/Applications/Swift Audio.app` after
  checking the existing app's bundle ID. It invokes `lsregister -f` and
  `pluginkit -a` for that bundle, not reset/unregister commands for all units.
- `package-au.py` deletes the generated `Swift Audio.app` in its selected output
  directory. It is a developer build script, not an installer shipped in the
  ZIP. With a custom `--output-dir` it can replace that same-named bundle there;
  it does not delete the parent directory or other components. The ZIP cleanup
  removes only its temporary staging directory.
- The actual archived and Qoder binaries each passed 30 cases on ARM and 30 on
  Intel through Rosetta: mono/stereo, 8/44.1/48/96/192 kHz, default/min/max
  parameters, save/restore, reset and an unknown maximum parameter address.
  All outputs were finite, all render calls succeeded, and the 135-entry
  in-process Audio Component inventory was identical before and after each run.
  This is a binary lifecycle/render smoke test, not a Logic session test.
- Reinstalled corrected 1.1.1/build 3 on the development Mac. Both strict
  in-process and out-of-process `auval` passed and reported component version
  1.1.1. Pre/post `auval -a` output and both Components directory inventories
  were byte-identical. The AUv3 list changed only our extension's version,
  registration UUID and timestamp. These snapshots are in
  `Build/audit-2026-11-09/{before,after}`. No other unit disappeared locally.
- The older C parameter store lacked its own bounds check, but host events were
  already matched to known addresses before indexing, and its allocated 128
  entries covered all used addresses (including meters). The new check is useful
  defensive programming, not proof of a prior host-triggerable overrun.
- Replacing `fatalError` on parameter-store allocation failure and removing
  editor force unwraps are also defensive improvements. We have no affected
  crash report tying either path to the incident. A process crash is a separate
  hypothesis from file deletion, and should not be reported as a confirmed cause.

### Ways the reported symptom can happen

| Observed symptom | Mechanism and evidence | How to distinguish it |
| --- | --- | --- |
| An effect disappears from one track after adding ours | Selecting a new effect in an occupied Audio FX slot replaces that instance. Old instructions did not explicitly say to use an empty slot. | The old effect still exists in Plug-in Manager and other tracks. Examine the slot and a saved project copy. |
| Only OliverJ or Swift Audio entries are visible | Manufacturer/search filters in Plug-in Manager or an open manufacturer submenu limit what is displayed. | Clear search, select Show All where available, and inspect the top-level menu. |
| An installed plug-in is absent from the insert menu | Depending on Logic version, Hide/Ignore/Use settings or failed validation can exclude it. | Record its row and Compatibility status before changing settings. |
| All third-party Audio Units are unavailable | Logic can be launched using “Launch Without Audio Units” after troubleshooting a startup problem. | Record any startup alert; compare a normal relaunch without that option. |
| Some features or ARA integrations change after installing our build | The old ARM instructions demanded native mode; the README said to match Logic's architecture. Changing native/Rosetta mode affects features/ARA integrations. | Record previous/current launch mode and names of affected products. Intel-only AUs do not universally require Logic itself to run under Rosetta. |
| Units are absent from Plug-in Manager but their files remain | Registration/validation/cache failure, possibly following a scan or host crash. | Compare component paths, system Audio Unit list, validation status and timestamped crash logs. No incident log currently supports a specific crash in our code. |
| Only our old channel strip disappears or the wrong UI loads | Shared identity across our releases and duplicate registered bundles. All earlier builds reported version 1.0/build 1. | Compare registered paths, app version and framework SHA256. This does not explain unrelated vendors disappearing. |
| Component files really disappeared | A file operation outside the inspected runtime/installer would need investigation. | Compare pre/post inventories, Trash/backups and exact manual steps; a missing menu alone is not evidence of deleted files. |

Apple's documentation supports the host mechanisms above:

- [Adding and replacing plug-ins](https://support.apple.com/en-il/guide/logicpro/lgcpbc218a22/mac)
- [Plug-in Manager, filtering and Hide/Ignore](https://support.apple.com/en-asia/guide/logicpro/lgcp9e26ef17/mac)
- [Missing plug-ins and validation](https://support.apple.com/en-ie/122179)
- [Launch Without Audio Units](https://support.apple.com/en-ie/109315)
- [Native/Rosetta compatibility and ARA](https://support.apple.com/en-gb/102082)
- [Features unavailable under Rosetta](https://support.apple.com/en-au/120406)

### Changes made during this review

- The hand-out now specifies an **empty** Audio FX slot on a new track or a
  project copy, retaining the user's usual Logic launch mode, and clearing
  menu filters before declaring other plug-ins missing.
- The installer no longer calls every other same-named copy “older” or tells
  the user to trash it without comparing versions.
- Version is now **1.1.1, build 3**, with matching AU component version. Bundle
  IDs and component codes are unchanged to preserve our existing instances.
  Each ZIP includes a binary SHA256 and architecture in `BUILD-INFO.txt`.
- Packaging selects the newer available framework when both native-default
  and explicit-architecture build directories exist. Previously an old
  `Build/arm64` could silently take precedence over a newer `Build` app.
- A separate confirmed DSP regression was corrected: Qoder's tail estimate
  divided unscaled 44.1 kHz tuning lengths by the current sample rate. At 96 kHz
  it reported 1.04 s against a measured 1.49 s decay; at 192 kHz 0.53 s against
  1.29 s. The estimate now uses the actual sample-rate-scaled delay lengths.
  The expanded decay regression failed before this change and passed after it
  across all five rates. This fixes bounce tail reporting, not plug-in discovery.

### Evidence needed on the affected Mac

1. Before resets or file moves, record one missing plug-in's name and whether it
   is missing from a track slot, Audio FX menu, or Plug-in Manager. Record Mac
   type, macOS/Logic versions, any startup/validation error and whether native/
   Rosetta mode changed.
2. Run the included `Collect-Diagnostics.command`, or
   `bash scripts/collect-au-diagnostics.sh` from a checkout. It writes a new
   private report folder on the Desktop. It only lists registrations/files,
   app versions/hashes and relevant crash-report paths. It does not reset a
   cache, validate, register, disable, delete or move a plug-in. Review local
   paths and installed plug-in names before sharing. Crash contents and Logic
   projects are not collected.
3. Capture the missing plug-in's Plug-in Manager row with search cleared and
   Show All selected where present. That host state is not available from
   `auval -a` alone. Connection/permission errors in a diagnostic command must
   not be interpreted as a genuinely empty registry.
4. Test in a new project/track while keeping the launch mode unchanged. If an
   error occurs, note its exact time and collect a second report. Compare the
   component paths and AU identities. This separates filesystem deletion,
   registration changes, and purely Logic-level visibility changes.
5. Only after preserving that evidence, use a targeted rescan for the affected
   unit when it has failed validation. A full AU reset or manual cache cleanup
   is a later troubleshooting step, not part of our installation procedure.

The diagnostic collector is included in both current ZIPs and requires only
macOS system tools. It cannot inspect another computer until its owner runs it
and supplies the results. The incident should remain open until that evidence
identifies which branch above actually occurred.
