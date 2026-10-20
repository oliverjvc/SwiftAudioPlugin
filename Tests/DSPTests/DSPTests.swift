// DSPTests.swift
// Unit tests for DSP components

import Foundation
import Testing
@testable import DSP

struct DSPTests {
    
    let sampleRate: Double = 44100
    let frameCount = 512
    
    // MARK: - Audio Buffer Tests
    
    @Test
    func testAudioBufferCreation() {
        let buffer = AudioBuffer(frameCount: 1024, channelCount: 2)
        #expect(buffer.frameCount == 1024)
        #expect(buffer.channelCount == 2)
        #expect(buffer.samples.count == 2048)
    }
    
    @Test
    func testAudioBufferInitialization() {
        let samples: [Float] = [0.5, -0.5, 0.3, -0.3]
        let buffer = AudioBuffer(samples: samples, channelCount: 2)
        #expect(buffer.frameCount == 2)
        #expect(buffer.samples[0] == 0.5)
    }
    
    // MARK: - Audio Utils Tests
    
    @Test
    func testDBToLinearConversion() {
        #expect(abs(AudioUtils.dBToLinear(0) - 1.0) <= 0.001)
        #expect(abs(AudioUtils.dBToLinear(-6) - 0.501) <= 0.01)
        #expect(abs(AudioUtils.dBToLinear(-20) - 0.1) <= 0.01)
    }
    
    @Test
    func testLinearToDBConversion() {
        #expect(abs(AudioUtils.linearToDB(1.0) - 0.0) <= 0.001)
        #expect(abs(AudioUtils.linearToDB(0.5) - -6.02) <= 0.1)
        #expect(abs(AudioUtils.linearToDB(0.1) - -20.0) <= 0.1)
    }
    
    @Test
    func testSoftClip() {
        // Below threshold - no change
        #expect(abs(AudioUtils.softClip(0.5) - 0.5) <= 0.001)
        
        // Above threshold - clipped
        let clipped = AudioUtils.softClip(1.5)
        #expect(clipped < 1.5)
        #expect(clipped > 0.9)
    }
    
    // MARK: - EQ Tests
    
    @Test
    func testEQBandCreation() {
        let band = EQBand(frequency: 1000, gain: 6, q: 1.5, type: .peak)
        #expect(band.frequency == 1000)
        #expect(band.gain == 6)
        #expect(band.q == 1.5)
        #expect(band.type == .peak)
    }
    
    @Test
    func testParametricEQCreation() {
        let eq = ParametricEQ(bandCount: 5, sampleRate: sampleRate)
        #expect(eq.bands.count == 5)
        #expect(eq.isEnabled)
    }
    
    @Test
    func testEQProcessing() {
        let eq = ParametricEQ(bandCount: 3, sampleRate: sampleRate)
        eq.bands[1].gain = 6.0  // Boost mids
        
        var buffer = generateSineWave(frequency: 1000, amplitude: 0.5)
        let originalRMS = calculateRMS(buffer)
        
        eq.process(&buffer)
        let processedRMS = calculateRMS(buffer)
        
        // With boost, processed should be louder
        #expect(processedRMS > originalRMS)
    }
    
    @Test
    func testEQBypass() {
        let eq = ParametricEQ(bandCount: 3, sampleRate: sampleRate)
        eq.bands[1].gain = 12.0
        eq.isEnabled = false
        
        var buffer = generateSineWave(frequency: 1000, amplitude: 0.5)
        let originalSamples = buffer.samples
        
        eq.process(&buffer)
        
        // When bypassed, samples should be unchanged
        #expect(buffer.samples == originalSamples)
    }

    @Test
    func testEQBandInitializesCoefficients() {
        for type in EQBandType.allCases {
            let band = EQBand(frequency: 1700, gain: 8, q: 1.7, type: type)
            let reference = EQBand(frequency: 1700, gain: 8, q: 1.7, type: type)
            reference.setSampleRate(sampleRate)
            assertMatchingImpulseResponse(band, reference)
        }
    }

    @Test
    func testEQBandParameterChangesRefreshCoefficients() {
        let changes: [(EQBand) -> Void] = [
            { $0.frequency = 1700 },
            { $0.gain = -8 },
            { $0.q = 2.5 },
            { $0.type = .highShelf }
        ]

        for change in changes {
            let band = EQBand(frequency: 1000, gain: 6, q: 1, type: .peak)
            band.setSampleRate(sampleRate)
            // Preserve the filter history while changing its settings.
            _ = band.processSample(left: 0.5, right: -0.5)
            let reference = EQBand(frequency: 1000, gain: 6, q: 1, type: .peak)
            reference.setSampleRate(sampleRate)
            _ = reference.processSample(left: 0.5, right: -0.5)

            change(band)
            change(reference)
            reference.updateCoefficients()
            assertMatchingImpulseResponse(band, reference)
        }
    }

    @Test
    func testEQSampleRateChangeUpdatesBands() {
        let eq = ParametricEQ(bandCount: 1, sampleRate: sampleRate)
        eq.bands[0].frequency = 1700
        eq.bands[0].gain = 8
        eq.bands[0].q = 1.7
        eq.bands[0].updateCoefficients()
        eq.sampleRate = 96000

        let reference = EQBand(frequency: 1700, gain: 8, q: 1.7)
        reference.setSampleRate(96000)
        assertMatchingImpulseResponse(eq.bands[0], reference)
    }
    
    // MARK: - Compressor Tests
    
    @Test
    func testCompressorCreation() {
        let comp = Compressor(sampleRate: sampleRate)
        #expect(comp.threshold == -20)
        #expect(comp.ratio == 4)
        #expect(comp.attack == 10)
        #expect(comp.release == 100)
    }
    
    @Test
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
        #expect(processedPeak < originalPeak)
    }
    
    @Test
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
        #expect(abs(processedRMS - originalRMS) <= 0.01)
    }
    
    // MARK: - Limiter Tests
    
    @Test
    func testLimiterCeiling() {
        let limiter = Limiter(sampleRate: sampleRate)
        limiter.ceiling = -3
        
        // Generate signal that exceeds ceiling
        var buffer = generateSineWave(frequency: 440, amplitude: 1.0)
        
        limiter.process(&buffer)
        
        // All samples should be below ceiling
        let ceilingLinear = AudioUtils.dBToLinear(-3)
        let peak = buffer.samples.map { abs($0) }.max() ?? 0
        #expect(peak <= ceilingLinear + 0.01)
    }
    
    // MARK: - Delay Tests
    
    @Test
    func testDelayCreation() {
        let delay = StereoDelay(sampleRate: sampleRate)
        #expect(delay.delayTimeL == 250)
        #expect(delay.delayTimeR == 250)
        #expect(delay.feedback == 0.4)
    }
    
    @Test
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
        #expect(abs(buffer.samples[0]) > 0.4)
    }
    
    // MARK: - Reverb Tests
    
    @Test
    func testReverbCreation() {
        let reverb = Reverb(sampleRate: sampleRate)
        #expect(reverb.roomSize == 0.5)
        #expect(reverb.damping == 0.5)
        #expect(reverb.width == 1.0)
    }
    
    @Test
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
        #expect(outputEnergy > 0)
    }
    
    // MARK: - Plugin Engine Tests
    
    @Test
    func testPluginEngineCreation() {
        let engine = PluginEngine(sampleRate: sampleRate)
        #expect(engine.eq.sampleRate == sampleRate)
        #expect(engine.compressor.sampleRate == sampleRate)
        #expect(engine.delay.sampleRate == sampleRate)
        #expect(engine.reverb.sampleRate == sampleRate)
    }
    
    @Test
    func testPluginEngineProcessing() {
        let engine = PluginEngine(sampleRate: sampleRate)
        
        var buffer = generateSineWave(frequency: 440, amplitude: 0.5)
        engine.process(&buffer)
        
        // Engine should process without crash
        #expect(buffer.frameCount == frameCount)
    }
    
    @Test
    func testPluginEngineBypass() {
        let engine = PluginEngine(sampleRate: sampleRate)
        engine.isBypassed = true
        
        var buffer = generateSineWave(frequency: 440, amplitude: 0.5)
        let originalSamples = buffer.samples
        
        engine.process(&buffer)
        
        // When bypassed, output should match input
        #expect(buffer.samples == originalSamples)
    }
    
    @Test
    func testPresetLoading() {
        let engine = PluginEngine(sampleRate: sampleRate)
        
        #expect(engine.presets.count > 0)
        
        if let preset = engine.presets.first {
            engine.loadPreset(preset)
            #expect(engine.currentPreset?.name == preset.name)
        }
    }
    
    // MARK: - Helper Functions

    private func assertMatchingImpulseResponse(
        _ actual: EQBand,
        _ reference: EQBand,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for frame in 0..<128 {
            let input: Float = frame == 0 ? 0.5 : 0
            let expected = reference.processSample(left: input, right: -input)
            let output = actual.processSample(left: input, right: -input)
            #expect(abs(output.0 - expected.0) <= 0.000001, sourceLocation: sourceLocation)
            #expect(abs(output.1 - expected.1) <= 0.000001, sourceLocation: sourceLocation)
        }
    }
    
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
