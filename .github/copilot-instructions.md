# Swift Audio Plugin - Copilot Instructions

## Project Overview
This is a professional audio plugin project similar to Waves Audio plugins, built in Swift.

## Architecture
- **DSP Core**: Audio processing algorithms (EQ, Compressor, Reverb)
- **AU Editor**: SwiftUI interface hosted by the Audio Unit
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
bash scripts/build-au.sh   # Package the AUv3 app
```

## File Structure
- `Sources/DSP/` - Audio processing algorithms
- `Sources/Plugin/` - Audio Unit wrapper and AU editor
- `Tests/` - Unit tests

## Cross-Platform Notes
- Primary target: macOS with Audio Unit
- Windows testing via Swift for Windows
- Core DSP code is platform-agnostic
