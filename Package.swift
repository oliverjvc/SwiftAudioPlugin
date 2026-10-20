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
        .library(name: "AudioUnitPlugin", type: .dynamic, targets: ["AudioUnitPlugin"]),
        // Main executable for standalone testing
        .executable(
            name: "SwiftAudioPlugin",
            targets: [
        .target(name: "ParameterAtomics"),
        .testTarget(name: "AudioUnitTests", dependencies: ["AudioUnitPlugin"], path: "Tests/AudioUnitTests"),"SwiftAudioPluginApp"]
        ),
        // DSP library (cross-platform)
        .library(
            name: "DSP",
            targets: [
        .target(name: "ParameterAtomics"),
        .testTarget(name: "AudioUnitTests", dependencies: ["AudioUnitPlugin"], path: "Tests/AudioUnitTests"),"DSP"]
        ),
        // UI library (SwiftUI-based)
        .library(
            name: "PluginUI",
            targets: [
        .target(name: "ParameterAtomics"),
        .testTarget(name: "AudioUnitTests", dependencies: ["AudioUnitPlugin"], path: "Tests/AudioUnitTests"),"PluginUI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(name: "ParameterAtomics"),
        .testTarget(name: "AudioUnitTests", dependencies: ["AudioUnitPlugin"], path: "Tests/AudioUnitTests"),
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
            dependencies: ["DSP", "ParameterAtomics"],
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
