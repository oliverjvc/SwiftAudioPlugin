# Classical Room Reverb — implementation and QA

Updated 2026-11-08 on macOS 26.3 / Apple Silicon / Swift 6.3.3. This review
describes the current product after moving from a multi-effect channel strip to
a deliberately simple room reverb.

## Product behavior

- One AU parameter, `Amount`, ranges from **0 to 100%**. At zero, the signal is
  dry; higher values raise the wet level of a fixed stereo room.
- Room size (0.68), damping (0.62), width (0.82), 24 ms pre-delay, dry level (1.0)
  and peak safety limiter are set internally. The user does not adjust them.
- Host tail time comes from the comb decay: 2.24 s reported, against a measured
  1.33 s RT60 at 48 kHz. An earlier build reported a flat 60 s, which a host
  would have appended to every bounce.
- The editor follows the supplied wood-panel reference: title, large dial, green
  active light and bypass. The dial supports vertical mouse/trackpad dragging and
  an accessibility value/action.
- Existing project state and historic AU parameter addresses remain loadable.
  The former EQ, compressor, delay and reverb controls do not change the new
  fixed sound. Old parameter values remain stored for project compatibility.
- Factory preset: Classical Room. Amount can be automated and stored with a Logic
  project. Rapid Amount automation is not smoothed and may click.

## Verification completed

- Full native Swift suite: **51 tests in four suites passed**. This includes the
  earlier soft-knee and pre-delay regressions, state round-trip, mono/stereo,
  8–192 kHz sample rates, varying block sizes, automation, bypass, limiter ceiling,
  and extreme parameter stress.
- New Amount regression verifies the 0–100% host range, dry output at 0, a wet
  response at 100%, and that legacy EQ/delay/compressor values do not alter the
  locked sound.
- New tail-time regressions compare the reported tail with a measured decay, and
  check the reported tail is zero at Amount 0 and while bypassed.
- The level test that used to read the removed meters now measures the rendered
  samples instead: Amount 0 gives an untouched dry signal, Output −6.02 dB
  halves it, bypass hands the input straight back, and reset restores the gain.
  Mono and stereo are both covered. Test count stays at 51.
- Full x86_64 Swift suite: **51 tests in four suites passed** under Rosetta.
- Strict in-process and out-of-process `auval` validation passed, repeated three
  times with no failing check. `auval` right after a reinstall used to report
  "didn't find the component"; `scripts/install-au.sh` now waits until the Audio
  Unit database lists the component, and validation succeeds immediately after.
- The AU editor was rendered offscreen from the installed framework and compared
  with the reference image: 640x700 wood panel, "Logic Pro" badge, serif
  "Classical Room Reverb" title, one dial with the green light beside it, an
  "Amount 42%" readout and a centred BYPASS pill. The reference's three extra
  knobs are absent by request. The host-visible Amount parameter reads 42 with a
  0–100 percent range, and the factory preset list is Classical Room.
- The same offscreen render was run against the previous build and the current
  one. Both PNGs are byte-identical (1,928,209 bytes, MD5 `e63a12cc…`), so the
  simplification below changed no pixel of the editor.
- Render cost was measured on both builds (48 kHz, stereo, 128-frame blocks,
  20,000 blocks per sample): 85.0 µs before, 84.4 µs after. The removed metering
  scans are a rounding error next to the comb filters; the benefit is code and
  per-instance state, not measurable CPU.
- Logic Pro playback and project save/reopen were not tested.

## Other plug-ins: audit result

- No code path deletes, moves or replaces anything except this project's own
  `Build/Swift Audio.app` and the installed `~/Applications/Swift Audio.app`.
  `scripts/install-au.sh` refuses to overwrite an app with a different bundle
  identifier, and neither it nor `scripts/package-au.py` or `scripts/share-au.py`
  writes into `Library/Audio/Plug-Ins/Components`.
- The AU registry (all six Audio Unit types), both Components folders and the
  `pluginkit` list were captured before and after reinstalling the current
  build. The only differences were this plug-in's own registration UUID and
  timestamp. `auval -s aufx` lists 24 effect units afterwards — the 23 Apple
  units plus ours — and no other vendor uses the `swft`/`Oliv` codes in any of
  the six Audio Unit types, so nothing was displaced. This Mac has no
  third-party Audio Units, so that is the extent of what could be observed here.
- The shipped instructions never asked anyone to remove other plug-ins. The
  current text says so explicitly, and adds the one real hazard found: a second
  copy of `Swift Audio.app` shares the bundle identifier, so a host can load the
  older build. The installer now lists such copies; nothing is deleted
  automatically, and the tester hand-out no longer tells anyone to move files
  near a Plug-Ins folder — it asks for the path instead.
- The remaining plausible mechanism is not deletion but a failed host scan. A
  plug-in that traps while a host loads it can abort that host's Audio Unit
  sweep, and the list then comes back short until the next rescan. This pass
  removed the three ways our own code could trap: allocation failure now throws
  an `OSStatus` error to the host instead of `fatalError` inside the extension
  process, the atomic parameter store bounds every index (previously it only
  looked safe because the count field it never checked was zeroed), and the
  editor no longer force-unwraps the parameter tree.

## Code removed in this pass

- `Sources/UI/` and `Sources/App/` (the original standalone demo app and its
  channel-strip panels, ~2,200 lines) plus their SwiftPM products. The AUv3
  never linked them: Logic loads the framework through the app extension, and
  `scripts/package-au.py` compiles only `AudioPlugin/HostApp/AppDelegate.swift`.
- Metering that no surface displayed: `MeterSnapshot`, its second atomic store,
  the six hidden meter addresses, `publishMeters`, and the two whole-buffer
  peak scans in `PluginEngine.process`. The AU editor has one knob and a light.
- Unused `SampleRate` enum, the never-rendered `ParameterValueField`, and the
  host app's Edit menu that existed only for numeric fields that are gone.
- Kept deliberately: the EQ, compressor and delay classes and their preset
  types. Their AU parameter addresses are part of the saved-project contract, so
  old Logic documents must keep decoding, and the DSP suite still tests them.
  They are instantiated but never process audio in room mode.

## Known release gaps

- No real Logic session, physical Intel Mac, offline bounce, long-session, or
  multi-instance test has been performed for the current redesign.
- The offscreen render does not realize SwiftUI accessibility elements, so the
  dial's VoiceOver label, value and increment actions were not re-verified in
  this pass; they are unchanged in code since the last check.
- The output limiter is sample-peak rather than true-peak; no oversampling or
  look-ahead is used. Rapid Amount moves can click.
- Packages are ad-hoc signed development builds without Apple notarization.
  Use Developer ID signing and notarization for public distribution.
- No listening comparison is claimed. The fixed room is a first usable sound,
  not a measured match for commercial reverbs.

Run native tests with `bash scripts/test.sh`. Build packages with
`bash scripts/build-au.sh` or `bash scripts/build-au.sh --arch x86_64`; on Apple
Silicon, run Intel tests under Rosetta with
`arch -x86_64 /bin/bash scripts/test.sh --arch x86_64`.
