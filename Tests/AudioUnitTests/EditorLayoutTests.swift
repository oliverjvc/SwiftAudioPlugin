#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import AudioUnitPlugin

struct EditorLayoutTests {
    @Test @MainActor func editorRendersAtSupportedSizes() throws {
        _ = NSApplication.shared
        let unit = try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
        let model = ParameterModel(unit: unit)
        model.set(51, 4)
        model.set(55, -3)
        model.set(59, 6)
        model.set(63, -2)
        let host = NSHostingView(rootView: PluginControls(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.orderOut(nil) }
        for (width, height) in [(960, 760), (760, 640)] {
            window.setContentSize(NSSize(width: width, height: height))
            host.layoutSubtreeIfNeeded()
            // Allow SwiftUI's initial layout/appearance pass on the main run loop.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
            host.layoutSubtreeIfNeeded()
            #expect(host.frame.width == CGFloat(width))
            #expect(host.frame.height == CGFloat(height))
            if let directory = ProcessInfo.processInfo.environment["SWIFT_AUDIO_SNAPSHOT_DIR"] {
                let folder = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: folder.appendingPathComponent("editor-\(width)x\(height).png"))
            }
        }
    }
}
#endif
