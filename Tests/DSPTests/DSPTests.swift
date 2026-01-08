// DSPTests.swift
// Unit tests for DSP components

import XCTest
@testable import DSP

final class DSPTests: XCTestCase {
    
    let sampleRate: Double = 44100
    let frameCount = 512
    
    // MARK: - Audio Buffer Tests
    
    func testAudioBufferCreation() {
        let buffer = AudioBuffer(frameCount: 1024, channelCount: 2)
        XCTAssertEqual(buffer.frameCount, 1024)
        XCTAssertEqual(buffer.channelCount, 2)
        XCTAssertEqual(buffer.samples.count, 2048)
    }
    
    func testAudioBufferInitialization() {
        let samples: [Float] = [0.5, -0.5, 0.3, -0.3]
        let buffer = AudioBuffer(samples: samples, channelCount: 2)
        XCTAssertEqual(buffer.frameCount, 2)
        XCTAssertEqual(buffer.samples[0], 0.5)
    }
    
    // MARK: - Audio Utils Tests
    
    func testDBToLinearConversion() {
        XCTAssertEqual(AudioUtils.dBToLinear(0), 1.0, accuracy: 0.001)
        XCTAssertEqual(AudioUtils.dBToLinear(-6), 0.501, accuracy: 0.01)
        XCTAssertEqual(AudioUtils.dBToLinear(-20), 0.1, accuracy: 0.01)
    }
    
    func testLinearToDBConversion() {
        XCTAssertEqual(AudioUtils.linearToDB(1.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(AudioUtils.linearToDB(0.5), -6.02, accuracy: 0.1)
        XCTAssertEqual(AudioUtils.linearToDB(0.1), -20.0, accuracy: 0.1)
    }
    
    func testSoftClip() {
        // Below threshold - no change
        XCTAssertEqual(AudioUtils.softClip(0.5), 0.5, accuracy: 0.001)
        
        // Above threshold - clipped
        let clipped = AudioUtils.softClip(1.5)
        XCTAssertLessThan(clipped, 1.5)
        XCTAssertGreaterThan(clipped, 0.9)
    }
    
    // MARK: - EQ Tests
    
    func testEQBandCreation() {
        let band = EQBand(frequency: 1000, gain: 6, q: 1.5, type: .peak)
        XCTAssertEqual(band.frequency, 1000)
        XCTAssertEqual(band.gain, 6)
        XCTAssertEqual(band.q, 1.5)
        XCTAssertEqual(band.type, .peak)
    }
    
    func testParametricEQCreation() {
        let eq = ParametricEQ(bandCount: 5, sampleRate: sampleRate)
        XCTAssertEqual(eq.bands.count, 5)
        XCTAssertTrue(eq.isEnabled)
    }
    
    func testEQProcessing() {
        let eq = ParametricEQ(bandCount: 3, sampleRate: sampleRate)
        eq.bands[1].gain = 6.0  // Boost mids
        
        var buffer = generateSineWave(frequency: 1000, amplitude: 0.5)
        let originalRMS = calculateRMS(buffer)
        
        eq.process(&buffer)
        let processedRMS = calculateRMS(buffer)
        
        // With boost, processed should be louder
        XCTAssertGreaterThan(processedRMS, originalRMS)
    }
    
    func testEQBypass() {
        let eq = ParametricEQ(bandCount: 3, sampleRate: sampleRate)
        eq.bands[1].gain = 12.0
        eq.isEnabled = false
        
        var buffer = generateSineWave(frequency: 1000, amplitude: 0.5)
        let originalSamples = buffer.samples
        
        eq.process(&buffer)
        
        // When bypassed, samples should be unchanged
        XCTAssertEqual(buffer.samples, originalSamples)
    }
    
    // MARK: - Compressor Tests
    
    func testCompressorCreation() {
        let comp = Compressor(sampleRate: sampleRate)
        XCTAssertEqual(comp.threshold, -20)
        XCTAssertEqual(comp.ratio, 4)
        XCTAssertEqual(comp.attack, 10)
        XCTAssertEqual(comp.release, 100)
    }
    
    func testCompressorGainReduction() {
        let comp = Compressor(sampleRate: sampleRate)
        comp.threshold = -20
        comp.ratio = 4
        
        // Generate loud signal that exceeds threshold
        var buffer = generateSineWave(frequency: 440, amplitude: 0.9)
        let originalPeak = buffer.samples.map { abs($0) }.max() ?? 0
        
        comp.process(&buffer)
        let processedPeak = buffer.samples.map { abs($0) }.max() ?? 0
        
        // Compressed signal should be quieter
        XCTAssertLessThan(processedPeak, originalPeak)
    }
    
    func testCompressorBelowThreshold() {
        let comp = Compressor(sampleRate: sampleRate)
        comp.threshold = -6
        comp.ratio = 10
        comp.knee = 0
        
        // Generate quiet signal below threshold
        var buffer = generateSineWave(frequency: 440, amplitude: 0.1)
        let originalRMS = calculateRMS(buffer)
        
        comp.process(&buffer)
        let processedRMS = calculateRMS(buffer)
        
        // Should be mostly unchanged (allowing for numerical precision)
        XCTAssertEqual(processedRMS, originalRMS, accuracy: 0.01)
    }
    
    // MARK: - Limiter Tests
    
    func testLimiterCeiling() {
        let limiter = Limiter(sampleRate: sampleRate)
        limiter.ceiling = -3
        
        // Generate signal that exceeds ceiling
        var buffer = generateSineWave(frequency: 440, amplitude: 1.0)
        
        limiter.process(&buffer)
        
        // All samples should be below ceiling
        let ceilingLinear = AudioUtils.dBToLinear(-3)
        let peak = buffer.samples.map { abs($0) }.max() ?? 0
        XCTAssertLessThanOrEqual(peak, ceilingLinear + 0.01)
    }
    
    // MARK: - Delay Tests
    
    func testDelayCreation() {
        let delay = StereoDelay(sampleRate: sampleRate)
        XCTAssertEqual(delay.delayTimeL, 250)
        XCTAssertEqual(delay.delayTimeR, 250)
        XCTAssertEqual(delay.feedback, 0.4)
    }
    
    func testDelayProcessing() {
        let delay = StereoDelay(sampleRate: sampleRate)
        delay.delayTimeL = 100
        delay.delayTimeR = 100
        delay.wetLevel = 0.5
        delay.dryLevel = 0.5
        delay.feedback = 0
        
        // Process impulse
        var buffer = AudioBuffer(frameCount: frameCount, channelCount: 2)
        buffer.samples[0] = 1.0  // Impulse on left
        buffer.samples[1] = 1.0  // Impulse on right
        
        delay.process(&buffer)
        
        // Check that dry signal is present
        XCTAssertGreaterThan(abs(buffer.samples[0]), 0.4)
    }
    
    // MARK: - Reverb Tests
    
    func testReverbCreation() {
        let reverb = Reverb(sampleRate: sampleRate)
        XCTAssertEqual(reverb.roomSize, 0.5)
        XCTAssertEqual(reverb.damping, 0.5)
        XCTAssertEqual(reverb.width, 1.0)
    }
    
    func testReverbProcessing() {
        let reverb = Reverb(sampleRate: sampleRate)
        reverb.wetLevel = 0.5
        reverb.preDelay = 0  // Remove pre-delay for test
        
        // Process impulse - use larger buffer to capture reverb tail
        var buffer = AudioBuffer(frameCount: 4096, channelCount: 2)
        buffer.samples[0] = 1.0
        buffer.samples[1] = 1.0
        
        reverb.process(&buffer)
        
        // Check that output contains signal (reverb produces output)
        let outputEnergy = buffer.samples.reduce(0) { $0 + abs($1) }
        XCTAssertGreaterThan(outputEnergy, 0)
    }
    
    // MARK: - Plugin Engine Tests
    
    func testPluginEngineCreation() {
        let engine = PluginEngine(sampleRate: sampleRate)
        XCTAssertNotNil(engine.eq)
        XCTAssertNotNil(engine.compressor)
        XCTAssertNotNil(engine.delay)
        XCTAssertNotNil(engine.reverb)
    }
    
    func testPluginEngineProcessing() {
        let engine = PluginEngine(sampleRate: sampleRate)
        
        var buffer = generateSineWave(frequency: 440, amplitude: 0.5)
        engine.process(&buffer)
        
        // Engine should process without crash
        XCTAssertEqual(buffer.frameCount, frameCount)
    }
    
    func testPluginEngineBypass() {
        let engine = PluginEngine(sampleRate: sampleRate)
        engine.isBypassed = true
        
        var buffer = generateSineWave(frequency: 440, amplitude: 0.5)
        let originalSamples = buffer.samples
        
        engine.process(&buffer)
        
        // When bypassed, output should match input
        XCTAssertEqual(buffer.samples, originalSamples)
    }
    
    func testPresetLoading() {
        let engine = PluginEngine(sampleRate: sampleRate)
        
        XCTAssertGreaterThan(engine.presets.count, 0)
        
        if let preset = engine.presets.first {
            engine.loadPreset(preset)
            XCTAssertEqual(engine.currentPreset?.name, preset.name)
        }
    }
    
    // MARK: - Helper Functions
    
    private func generateSineWave(frequency: Float, amplitude: Float) -> AudioBuffer {
        var buffer = AudioBuffer(frameCount: frameCount, channelCount: 2)
        
        for i in 0..<frameCount {
            let t = Float(i) / Float(sampleRate)
            let sample = amplitude * sin(2.0 * Float.pi * frequency * t)
            buffer.samples[i * 2] = sample
            buffer.samples[i * 2 + 1] = sample
        }
        
        return buffer
    }
    
    private func calculateRMS(_ buffer: AudioBuffer) -> Float {
        let sumSquares = buffer.samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumSquares / Float(buffer.samples.count))
    }
}
