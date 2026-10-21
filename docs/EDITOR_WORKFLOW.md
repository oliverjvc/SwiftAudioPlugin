# AU editor workflow improvements — 2026-10-21

Based on Mac commit e1c4618. This pass changes the installed Audio Unit editor
and the containing app's initial window size. The old standalone demo is separate.

## Implemented

- Dark channel-strip layout with processor navigation, colored band selection,
  rotary/numeric controls, stereo input/output meters and gain-reduction bars.
- EQ response computed from the DSP biquad coefficients, with logarithmic
  frequency positioning and draggable frequency/gain nodes. At low sample rates,
  the graph follows the AU's existing 0.45 × sample-rate frequency clamp.
- Module reset and 100-step editor undo/redo. Knob, slider and EQ-node drags are
  grouped; numeric edits, factory presets, A/B copy/switch and imports are undoable.
  History and comparison slots are local to an open editor.
- Named user JSON preset import/export through system file dialogs, including
  all 50 AU parameters and bypass. Stable identifiers are used, not array indices.
  Format/version, required parameters, finite values, ranges and Boolean values
  are checked before any parameter is changed. Unknown extra fields are ignored.
  Files are limited to less than 1 MB when imported through the editor.
- macOS CI builds, runs DSP/AU tests, renders default/minimum-size editor previews
  and packages an ad-hoc development app. Its ZIP preserves app bundle metadata.
  CI artifacts are development builds; they are not notarized releases.

## Contracts

The 50 AU parameter addresses, ranges, defaults, version-1 host state, component
identity, buses, automation events and render loop are retained. DSP processing
order is unchanged. The magnitude-response query does not process audio or
advance filter history. Visualizers instantiate their own bands on the UI side.

The imported JSON format is specifically the AU editor format. It is not a DSP
PluginPreset JSON file or an .aupreset. Existing Logic state and presets continue
to use the Audio Unit state contract. Imports and editor history can change all
exposed parameters, including bypass, just like A/B.

## Validation

New tests compare plotted EQ magnitude with the Fourier transform of a rendered
impulse for all six DSP filter types at 44.1/48/96/192 kHz. Other tests cover
non-mutating response queries, grouped undo, redo invalidation, history limits,
host automation checkpoints, module reset, A/B history, complete JSON round-trip,
and rejection of invalid imports without partial application.

Reproduce on macOS:

    swift build
    bash scripts/test.sh
    bash scripts/build-au.sh

Set SWIFT_AUDIO_SNAPSHOT_DIR to an output directory when running tests to save
editor PNGs at 960×760 and 760×640. Inspect those alongside a Logic Pro session:
drag EQ nodes, type values, use fine adjustment, change tabs, undo/redo,
import/export files, automate parameters, and save/reopen the Logic project.

The Windows editing host does not have Swift or Apple's frameworks; local
macOS compilation and Logic playback cannot run there. GitHub CI provides
build/test evidence separately. A successful offscreen render does not establish
interaction or audio behavior inside Logic Pro.

## Still outside this pass

Live FFT spectrum, dynamic/mid-side EQ, selectable AU filter types, sidechain
compression, tempo-sync AU controls, true-peak limiting and oversampling are not
implemented. Existing step-change/preset switching can click; parameter smoothing
and delay crossfades remain a separate DSP task. No commercial sound-quality
equivalence is claimed.
