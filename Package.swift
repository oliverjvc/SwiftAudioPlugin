// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftAudioPlugin",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DSP", targets: ["DSP"]),
        .library(name: "AudioUnitPlugin", type: .dynamic, targets: ["AudioUnitPlugin"])
    ],
    targets: [
        .target(name: "DSP", path: "Sources/DSP"),
        .target(name: "ParameterAtomics"),
        .target(name: "AudioUnitPlugin", dependencies: ["DSP", "ParameterAtomics"], path: "Sources/Plugin"),
        .testTarget(name: "DSPTests", dependencies: ["DSP"], path: "Tests/DSPTests"),
        .testTarget(name: "AudioUnitTests", dependencies: ["AudioUnitPlugin"], path: "Tests/AudioUnitTests")
    ]
)
