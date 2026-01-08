// Delay.swift
// Stereo delay effect with tempo sync and modulation

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Delay effect with feedback and filtering
public class StereoDelay: BaseAudioProcessor, PlatformObservable {
    // Parameters
    public var delayTimeL: Float = 250.0   // ms
    public var delayTimeR: Float = 250.0   // ms
    public var feedback: Float = 0.4       // 0-1
    public var wetLevel: Float = 0.3
    public var dryLevel: Float = 1.0
    public var pingPong: Bool = false
    public var highCut: Float = 8000.0     // Hz
    public var lowCut: Float = 100.0       // Hz
    public var tempo: Float = 120.0        // BPM (for sync)
    public var syncEnabled: Bool = false
    public var syncDivisionL: Float = 0.25 // quarter note
    public var syncDivisionR: Float = 0.25
    
    // Internal state
    private var bufferL: [Float] = []
    private var bufferR: [Float] = []
    private var writeIndexL: Int = 0
    private var writeIndexR: Int = 0
    private var maxDelaySamples: Int = 0
    
    // High-cut filter state
    private var hcStateL: Float = 0.0
    private var hcStateR: Float = 0.0
    
    // Low-cut filter state
    private var lcStateL: Float = 0.0
    private var lcStateR: Float = 0.0
    
    public override init(sampleRate: Double = 44100.0) {
        super.init(sampleRate: sampleRate)
        // Max 2 seconds delay
        maxDelaySamples = Int(sampleRate * 2.0)
        bufferL = [Float](repeating: 0.0, count: maxDelaySamples)
        bufferR = [Float](repeating: 0.0, count: maxDelaySamples)
    }
    
    private func getDelayTimeSamples(ms: Float, division: Float) -> Int {
        if syncEnabled {
            // Calculate delay from tempo and division
            let beatTime = 60.0 / tempo  // seconds per beat
            let delaySeconds = beatTime * division * 4.0  // division is in quarter notes
            return min(Int(delaySeconds * Float(sampleRate)), maxDelaySamples - 1)
        } else {
            return min(Int(ms * Float(sampleRate) / 1000.0), maxDelaySamples - 1)
        }
    }
    
    public override func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }
        
        let delaySamplesL = getDelayTimeSamples(ms: delayTimeL, division: syncDivisionL)
        let delaySamplesR = getDelayTimeSamples(ms: delayTimeR, division: syncDivisionR)
        
        // Filter coefficients
        let hcCoeff = expf(-2.0 * Float.pi * highCut / Float(sampleRate))
        let lcCoeff = expf(-2.0 * Float.pi * lowCut / Float(sampleRate))
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            let rightIdx = leftIdx + 1
            
            let inputL = buffer.samples[leftIdx]
            let inputR = buffer.channelCount > 1 ? buffer.samples[rightIdx] : inputL
            
            // Read from delay buffers
            let readIndexL = (writeIndexL - delaySamplesL + maxDelaySamples) % maxDelaySamples
            let readIndexR = (writeIndexR - delaySamplesR + maxDelaySamples) % maxDelaySamples
            
            var delayedL = bufferL[readIndexL]
            var delayedR = bufferR[readIndexR]
            
            // Apply high-cut filter
            hcStateL = hcCoeff * hcStateL + (1.0 - hcCoeff) * delayedL
            delayedL = hcStateL
            hcStateR = hcCoeff * hcStateR + (1.0 - hcCoeff) * delayedR
            delayedR = hcStateR
            
            // Apply low-cut filter (high-pass)
            lcStateL = lcCoeff * lcStateL + (1.0 - lcCoeff) * delayedL
            delayedL = delayedL - lcStateL
            
            lcStateR = lcCoeff * lcStateR + (1.0 - lcCoeff) * delayedR
            delayedR = delayedR - lcStateR
            
            // Write to delay buffers with feedback
            if pingPong {
                // Ping-pong: cross-feed the channels
                bufferL[writeIndexL] = inputL + delayedR * feedback
                bufferR[writeIndexR] = inputR + delayedL * feedback
            } else {
                bufferL[writeIndexL] = inputL + delayedL * feedback
                bufferR[writeIndexR] = inputR + delayedR * feedback
            }
            
            // Advance write indices
            writeIndexL = (writeIndexL + 1) % maxDelaySamples
            writeIndexR = (writeIndexR + 1) % maxDelaySamples
            
            // Mix output
            buffer.samples[leftIdx] = inputL * dryLevel + delayedL * wetLevel
            if buffer.channelCount > 1 {
                buffer.samples[rightIdx] = inputR * dryLevel + delayedR * wetLevel
            }
        }
    }
    
    public override func reset() {
        bufferL = [Float](repeating: 0.0, count: maxDelaySamples)
        bufferR = [Float](repeating: 0.0, count: maxDelaySamples)
        writeIndexL = 0
        writeIndexR = 0
        hcStateL = 0.0
        hcStateR = 0.0
        lcStateL = 0.0
        lcStateR = 0.0
    }
}
