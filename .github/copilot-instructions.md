# Swift Audio Plugin - Copilot Instructions

## Project Overview
This is a professional audio plugin project similar to Waves Audio plugins, built in Swift.

## Architecture
- **DSP Core**: Audio processing algorithms (EQ, Compressor, Reverb)
- **UI Layer**: SwiftUI-based professional audio plugin interface
- **Plugin Host**: Audio Unit v3 wrapper for macOS DAW compatibility

## Development Guidelines
- Target: macOS (Apple Silicon M2) with Windows 11 testing support
- Use Swift Package Manager for dependencies
- Follow Apple's Audio Unit v3 guidelines
- Maintain 44.1kHz/48kHz sample rate compatibility

## Build Commands
```bash
swift build          # Build the project
swift test           # Run tests
swift run            # Run standalone version
```

## File Structure
- `Sources/DSP/` - Audio processing algorithms
- `Sources/UI/` - SwiftUI components
- `Sources/Plugin/` - Audio Unit wrapper
- `Tests/` - Unit tests

## Cross-Platform Notes
- Primary target: macOS with Audio Unit
- Windows testing via Swift for Windows
- Core DSP code is platform-agnostic
