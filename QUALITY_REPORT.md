# Quality review — 2026-10-20

## Assessment

Swift Audio is a usable early channel-strip prototype, not yet a demonstrated
replacement for established commercial plugins. The current pass improves DSP
correctness and editing workflow. Feature comparisons below use vendor documents;
no competing binaries were installed, benchmarked or auditioned. Sound quality
parity and market competitiveness cannot be inferred from passing unit tests.

## Changes

- Corrected the compressor's quadratic soft knee. Previously it could amplify
  signals just below threshold and failed to join the above-threshold curve
  smoothly. Regression tests check seven input levels against the expected curve.
- Corrected reverb pre-delay indexing. At 48 kHz, zero pre-delay previously produced
  the first wet impulse at sample 10813 instead of 1214. The corrected response
  also shifts by exactly 480 samples for a 10 ms pre-delay.
- Added stereo input/output peak meters and compressor/limiter gain-reduction
  readouts through atomic scalar storage. Input meters measure before input gain;
  mono reads identically on L/R; bypass and reset are handled. Level meters use
  instant peak attack and a 24 dB/second decay; GR smoothing uses elapsed samples.
- Added factory preset selection, A/B parameter comparison and copy-to-other-slot.
  A/B includes bypass and all 50 parameters. Slots last while the editor is open;
  the active parameter state is saved by the host. Tail histories are not copied.
- Added numeric entry (Return or focus loss to commit), range clamping and a
  right-click reset-to-default action. Preview app includes standard Edit shortcuts.
- Retained sample addresses and version-1 state compatibility. Existing projects
  load, but corrected compressor/reverb behavior can change their sound.

## Verification

Environment: macOS 26.3, Apple Silicon, Swift 6.3.3 / Command Line Tools.

- Full native suite: 49 tests in four suites passed, including parameterized cases.
- Full x86_64 suite: 49 tests passed under Rosetta.
- Native and Intel release apps built and signed ad hoc.
- Apple Silicon strict `auval`: in-process and out-of-process passed.
- Tests cover AU resource allocation, variable buffer sizes, mono/stereo, sample
  rates 8–192 kHz, automation and cross-block ramps, state serialization, factory
  presets, A/B copy/restore, metering, limiter ceiling and extreme parameter stress.
- The new soft-knee and pre-delay regressions failed against the old DSP and pass
  after the corrections. The limiter bounds test passed before and after.
- Preview UI inspected for layout and numeric entry, factory presets and A/B.

Release throughput diagnostic (48 kHz stereo, 128 frames, default full chain,
1,000 renders): mean **0.116 ms**, p95 **0.136 ms**, maximum **1.200 ms**;
buffer duration **2.667 ms**. Includes test harness allocation/copies and runs
without a DAW. This is not a CPU-utilization reading, a real-time scheduling
guarantee, an automation stress benchmark or a comparison with commercial DSP.
Debug/Rosetta timings printed by the regular suite are not release benchmarks.

Reproduce native tests with `bash scripts/test.sh`; Intel on Apple Silicon with
`arch -x86_64 /bin/bash scripts/test.sh --arch x86_64` (requires Rosetta).
Run the diagnostic alone: `bash scripts/test.sh -c release --filter renderTimingDiagnostic`.
Local raw logs are in `Build/quality-after.log`, `Build/quality-x86_64.log`,
`Build/timing-arm64.log`, `Build/auval-quality.log` and `Build/auval-quality-oop.log`.

## Market comparison

| Reference | Documented features beyond this plugin | Implication |
| --- | --- | --- |
| [SSL Channel Strip 2](https://support.solidstatelogic.com/hc/en-gb/articles/6887173070877-SSL-Channel-Strip-2-Plug-in-User-Guide) | Gate/expander, side-chain input and filtering, shelves/HP/LP, parallel compression, flexible routing, HQ mode, undo/redo | Most relevant channel-strip workflow benchmark. Prioritize flexible filters, parallel mix and undo before expanding the effect count. |
| [FabFilter Pro-Q 4](https://www.fabfilter.com/products/pro-q-4-equalizer-plug-in) | Interactive EQ display, spectrum analysis, dynamic/spectral EQ, mid/side, phase modes, automatic gain | A specialized EQ benchmark, not an equivalent all-in-one product. Current five fixed peak bands and sliders offer a much smaller feature set. |
| [iZotope Neutron 5](https://www.izotope.com/products/Neutron) | Assisted mixing, multiband and mid/side processing, clipping and advanced visual feedback | A much broader mixing suite. No equivalent intelligent or multiband processing is implemented here. |

## Remaining release gates and priorities

1. Test real Logic sessions on Apple Silicon and physical Intel: scan, mono/stereo
   playback, fast automation, bypass, stop/start, project save/reopen, offline bounce,
   multiple instances, CPU load and long sessions. Test minimum macOS 13 too.
2. Level-matched listening on vocals, drums, bass and full mixes against Logic's
   stock processors. Evaluate distortion, transients, reverb tails and delay edits.
   No listening study or commercial sound-quality claim is made in this review.
3. Add parameter/bypass smoothing and delay-time crossfades. Host ramps work,
   but abrupt step changes and preset/A/B switches can still click.
4. Add an EQ curve/spectrum display, selectable shelves/cuts, tempo-sync delay,
   undo/redo, persistent A/B, and user preset management in the editor.
5. Current limiter is sample-peak, not true-peak; no look-ahead or oversampling.
   Metering is peak/GR, not LUFS or true-peak. Do not market as a mastering limiter.
6. Developer ID signing, notarization and a tested installer are needed for smooth
   public distribution. Current ZIPs are development packages, macOS 13+, AU only.

The standalone window previews controls; audio processing runs in an AU host.
