// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAudioPlugin",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Main executable for standalone testing
        .executable(
            name: "SwiftAudioPlugin",
            targets: ["SwiftAudioPluginApp"]
        ),
        // DSP library (cross-platform)
        .library(
            name: "DSP",
            targets: ["DSP"]
        ),
        // UI library (SwiftUI-based)
        .library(
            name: "PluginUI",
            targets: ["PluginUI"]
        )
    ],
    dependencies: [],
    targets: [
        // DSP Core - Audio processing algorithms
        .target(
            name: "DSP",
            dependencies: [],
            path: "Sources/DSP"
        ),
        // Plugin UI - SwiftUI components
        .target(
            name: "PluginUI",
            dependencies: ["DSP"],
            path: "Sources/UI"
        ),
        // Audio Unit Plugin (macOS only)
        .target(
            name: "AudioUnitPlugin",
            dependencies: ["DSP", "PluginUI"],
            path: "Sources/Plugin"
        ),
        // Standalone application for testing
        .executableTarget(
            name: "SwiftAudioPluginApp",
            dependencies: ["DSP", "PluginUI"],
            path: "Sources/App"
        ),
        // Tests
        .testTarget(
            name: "DSPTests",
            dependencies: ["DSP"],
            path: "Tests/DSPTests"
        )
    ]
)
