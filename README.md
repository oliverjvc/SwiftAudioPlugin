# Swift Audio Plugin

Professional audio plugin similar to Waves Audio plugins, built entirely in Swift.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### DSP Effects
- **5-Band Parametric EQ** - Professional equalizer with adjustable frequency, gain, Q, and filter types
- **Dynamics Compressor** - Full-featured compressor with threshold, ratio, attack, release, knee, and makeup gain
- **Stereo Delay** - Tempo-syncable delay with ping-pong mode, feedback, and filtering
- **Algorithmic Reverb** - Freeverb-style reverb with room size, damping, width, and pre-delay
- **Brick-wall Limiter** - Final stage limiting for safe output levels

### User Interface
- Modern dark theme with professional audio plugin aesthetics
- Rotary knobs with visual feedback
- Real-time level meters with peak hold
- Gain reduction visualization
- EQ frequency response curve with draggable band points
- Compression transfer curve display
- Preset management system

## Requirements

### macOS (Primary Platform)
- macOS 13.0+ (Ventura or later)
- Swift 5.9+ for building, from Xcode or Apple Command Line Tools
- Swift 6+ for the Swift Testing test suite
- Apple Silicon (M1/M2) or Intel Mac

### Windows (Testing/Development)
- Windows 10/11
- Swift for Windows (install via winget: `winget install Swift.Toolchain`)
- Note: GUI requires macOS; Windows runs DSP in console mode

## Installation

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/oliverjvc/SwiftAudioPlugin.git
cd SwiftAudioPlugin

# Build the project
swift build

# Run tests
bash scripts/test.sh

# Run standalone app (macOS with GUI, Windows console mode)
swift run
```

### Xcode (macOS)

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Or open directly in Xcode
open Package.swift
```

## Project Structure

```
Plugin/
├── Package.swift              # Swift Package Manager manifest
├── Sources/
│   ├── DSP/                   # Audio processing (cross-platform)
│   │   ├── AudioProcessor.swift    # Base protocols and utilities
│   │   ├── Equalizer.swift         # Parametric EQ
│   │   ├── Compressor.swift        # Dynamics compressor & limiter
│   │   ├── Delay.swift             # Stereo delay effect
│   │   ├── Reverb.swift            # Algorithmic reverb
│   │   └── PluginEngine.swift      # Main processing chain
│   │
│   ├── UI/                    # SwiftUI interface (macOS/iOS)
│   │   ├── Theme.swift             # Colors, fonts, styling
│   │   ├── MainPluginView.swift    # Main plugin window
│   │   ├── Components/             # Reusable UI components
│   │   │   ├── Knob.swift          # Rotary controls
│   │   │   ├── Meter.swift         # Level meters
│   │   │   └── Buttons.swift       # Toggle/action buttons
│   │   └── Panels/                 # Effect-specific panels
│   │       ├── EQView.swift
│   │       ├── CompressorView.swift
│   │       ├── DelayView.swift
│   │       └── ReverbView.swift
│   │
│   ├── Plugin/                # Audio Unit wrapper (macOS)
│   │   └── AudioUnitPlugin.swift   # AU v3 implementation
│   │
│   └── App/                   # Standalone application
│       └── SwiftAudioPluginApp.swift
│
└── Tests/
    └── DSPTests/              # Unit tests for DSP
        └── DSPTests.swift
```

## Usage

### Standalone Application (macOS)

Run the standalone app to test the plugin without a DAW:

```bash
swift run SwiftAudioPlugin
```

### Audio Unit Plugin

The plugin registers as an Audio Unit v3 effect that can be loaded in any compatible DAW (Logic Pro, GarageBand, Ableton Live, etc.).

### Windows Console Mode

On Windows, the application runs in console mode and tests all DSP components:

```bash
swift run
```

## DSP Architecture

### Signal Flow

```
Input → Input Gain → EQ → Compressor → Delay → Reverb → Limiter → Output Gain → Output
```

### Sample Rates
- Supports 44.1kHz, 48kHz, 96kHz, and 192kHz
- Automatic coefficient recalculation on sample rate change

### Buffer Processing
- Efficient block-based processing
- Zero-latency processing (no lookahead)
- Denormal prevention

## UI Components

### Knob Control
- Vertical drag for value adjustment
- Double-click to reset to default
- Shift+drag for fine adjustment
- Visual indicator and value display

### Level Meters
- Stereo metering with peak hold
- Gain reduction display
- Clip indicators

### EQ Curve
- Interactive frequency response display
- Draggable band control points
- Real-time curve updates

## Presets

Factory presets included:
- **Warm Vocal** - Smooth vocal processing
- **Punchy Drums** - Aggressive drum compression
- **Ambient Pad** - Lush reverb and delay

Save and load your own presets through the preset manager.

## Development

### Adding New Effects

1. Create a new processor in `Sources/DSP/` implementing `AudioProcessor` protocol
2. Add to the processing chain in `PluginEngine.swift`
3. Create corresponding UI panel in `Sources/UI/Panels/`
4. Add parameters to Audio Unit wrapper if needed

### Running Tests

The test suite uses Swift Testing and requires Swift 6 or newer. On macOS
with Command Line Tools, use the wrapper to locate the bundled testing
framework and its runtime libraries:

```bash
bash scripts/test.sh
```

The wrapper runs `swift test` with the necessary search paths and forwards
additional arguments, such as `--filter testEQ`. With a toolchain that already
provides those paths (such as a full Xcode installation), run directly:

```bash
swift test
```

The bundled testing runtime may require a newer macOS version than the app's
macOS 13 deployment target. The Command Line Tools runtime used for validation
requires macOS 14 or newer; this does not change the app's deployment target.

### Code Style
- Follow Swift API Design Guidelines
- Use `@Published` for observable properties
- Keep DSP code platform-agnostic

## Known Limitations

- Windows: No GUI support (SwiftUI requires macOS/iOS)
- Audio Unit: macOS only (AU v3 is Apple's format)
- No VST/VST3 support yet (would require C++ bridging)

## Future Enhancements

- [ ] VST3 wrapper for cross-platform DAW support
- [ ] Additional effects (chorus, phaser, saturation)
- [ ] MIDI learn for parameter control
- [ ] A/B comparison feature
- [ ] Undo/redo system
- [ ] Oversampling for improved analog character

## License

MIT License - See LICENSE file for details.

## Credits

Built with Swift and SwiftUI by the development team.
Inspired by professional audio plugins from Waves Audio, FabFilter, and others.
