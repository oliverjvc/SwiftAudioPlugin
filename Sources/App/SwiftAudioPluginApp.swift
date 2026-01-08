// SwiftAudioPluginApp.swift
// Standalone application for testing the audio plugin

#if canImport(SwiftUI)
import SwiftUI
import DSP
import PluginUI

@main
struct SwiftAudioPluginApp: App {
    var body: some Scene {
        WindowGroup {
            MainPluginView()
                .frame(minWidth: 700, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
#else
// Fallback for platforms without SwiftUI (Windows testing)
import Foundation
import DSP

@main
struct SwiftAudioPluginApp {
    static func main() {
        print("Swift Audio Plugin - Console Mode")
        print("==================================")
        print("SwiftUI is not available on this platform.")
        print("Running DSP tests instead...\n")
        
        // Test DSP components
        testDSP()
    }
    
    static func testDSP() {
        print("Testing DSP Components:")
        print("-----------------------")
        
        // Test audio buffer
        var buffer = AudioBuffer(frameCount: 1024, channelCount: 2)
        print("✓ AudioBuffer created: \(buffer.frameCount) frames, \(buffer.channelCount) channels")
        
        // Generate test signal (sine wave)
        let frequency: Float = 440.0  // A4
        let sampleRate: Float = 44100.0
        for i in 0..<buffer.frameCount {
            let t = Float(i) / sampleRate
            let sample = Foundation.sin(2.0 * Float.pi * frequency * t) * 0.5
            buffer.samples[i * 2] = sample      // Left
            buffer.samples[i * 2 + 1] = sample  // Right
        }
        print("✓ Test signal generated: 440Hz sine wave")
        
        // Test EQ
        let eq = ParametricEQ(bandCount: 5, sampleRate: Double(sampleRate))
        eq.bands[2].gain = 6.0  // Boost mid frequencies
        eq.process(&buffer)
        print("✓ Parametric EQ processed")
        
        // Test Compressor
        let compressor = Compressor(sampleRate: Double(sampleRate))
        compressor.threshold = -20
        compressor.ratio = 4
        compressor.process(&buffer)
        print("✓ Compressor processed")
        
        // Test Delay
        let delay = StereoDelay(sampleRate: Double(sampleRate))
        delay.delayTimeL = 250
        delay.delayTimeR = 375
        delay.feedback = 0.4
        delay.process(&buffer)
        print("✓ Stereo Delay processed")
        
        // Test Reverb
        let reverb = Reverb(sampleRate: Double(sampleRate))
        reverb.roomSize = 0.7
        reverb.wetLevel = 0.3
        reverb.process(&buffer)
        print("✓ Reverb processed")
        
        // Test Plugin Engine
        let engine = PluginEngine(sampleRate: Double(sampleRate))
        engine.process(&buffer)
        print("✓ Plugin Engine processed full chain")
        
        // Check output levels
        var maxLevel: Float = 0
        for sample in buffer.samples {
            maxLevel = max(maxLevel, abs(sample))
        }
        let outputDB = AudioUtils.linearToDB(maxLevel)
        print("\n📊 Output peak level: \(outputDB) dB")
        
        print("\n✅ All DSP tests passed!")
        print("\nTo run with GUI, build on macOS with SwiftUI support.")
    }
}
#endif
