// Compressor.swift
// Professional dynamics compressor implementation

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Compressor with attack, release, ratio, threshold, and makeup gain
public class Compressor: BaseAudioProcessor, PlatformObservable {
    // Parameters
    public var threshold: Float = -20.0      // dB
    public var ratio: Float = 4.0           // ratio:1
    public var attack: Float = 10.0         // ms
    public var release: Float = 100.0       // ms
    public var makeupGain: Float = 0.0      // dB
    public var knee: Float = 6.0            // dB (soft knee width)
    
    // Metering
    public var inputLevel: Float = -60.0    // dB (for meters)
    public var outputLevel: Float = -60.0   // dB
    public var gainReduction: Float = 0.0   // dB
    
    // Internal state
    private var envelope: Float = 0.0
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    
    public override init(sampleRate: Double = 44100.0) {
        super.init(sampleRate: sampleRate)
        updateCoefficients()
    }
    
    public func updateCoefficients() {
        // Convert ms to coefficient
        attackCoeff = expf(-1.0 / (Float(sampleRate) * attack / 1000.0))
        releaseCoeff = expf(-1.0 / (Float(sampleRate) * release / 1000.0))
    }
    
    private func computeGain(inputDB: Float) -> Float {
        // Soft knee computation
        let kneeStart = threshold - knee / 2.0
        let kneeEnd = threshold + knee / 2.0
        
        if inputDB <= kneeStart {
            // Below knee - no compression
            return 0.0
        } else if inputDB >= kneeEnd {
            // Above knee - full compression
            return (threshold - inputDB) * (1.0 - 1.0 / ratio)
        } else {
            // Quadratic knee matches both the value and slope of the two straight
            // segments. Gain reduction must never become positive below threshold.
            let distance = inputDB - kneeStart
            return (1.0 / ratio - 1.0) * distance * distance / (2.0 * knee)
        }
    }
    
    public override func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }
        
        updateCoefficients()
        
        let makeupLinear = AudioUtils.dBToLinear(makeupGain)
        var peakInput: Float = 0.0
        var peakOutput: Float = 0.0
        var maxGainReduction: Float = 0.0
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            let rightIdx = leftIdx + 1
            
            let left = buffer.samples[leftIdx]
            let right = buffer.channelCount > 1 ? buffer.samples[rightIdx] : left
            
            // Get peak of stereo signal
            let peak = max(abs(left), abs(right))
            let inputDB = AudioUtils.linearToDB(peak)
            
            // Track peak for metering
            peakInput = max(peakInput, peak)
            
            // Compute desired gain reduction
            let targetGainDB = computeGain(inputDB: inputDB)
            
            // Apply envelope follower
            let coeff = targetGainDB < envelope ? attackCoeff : releaseCoeff
            envelope = coeff * envelope + (1.0 - coeff) * targetGainDB
            
            // Convert gain reduction to linear
            let gainLinear = AudioUtils.dBToLinear(envelope) * makeupLinear
            
            // Apply gain
            buffer.samples[leftIdx] = left * gainLinear
            if buffer.channelCount > 1 {
                buffer.samples[rightIdx] = right * gainLinear
            }
            
            // Track output and gain reduction
            peakOutput = max(peakOutput, max(abs(left), abs(right)) * gainLinear)
            maxGainReduction = min(maxGainReduction, envelope)
        }
        
        // Update meters with smoothing
        let meterSmooth = expf(-Float(buffer.frameCount) / (Float(sampleRate) * 0.1))
        inputLevel = meterSmooth * inputLevel + (1.0 - meterSmooth) * AudioUtils.linearToDB(peakInput)
        outputLevel = meterSmooth * outputLevel + (1.0 - meterSmooth) * AudioUtils.linearToDB(peakOutput)
        gainReduction = meterSmooth * gainReduction + (1.0 - meterSmooth) * (-maxGainReduction)
    }
    
    public override func reset() {
        envelope = 0.0
        inputLevel = -60.0
        outputLevel = -60.0
        gainReduction = 0.0
    }
}

/// Limiter (compressor with infinite ratio)
public class Limiter: BaseAudioProcessor, PlatformObservable {
    public var ceiling: Float = -0.3      // dB
    public var release: Float = 50.0     // ms
    
    public var gainReduction: Float = 0.0
    
    private var envelope: Float = 1.0
    private var releaseCoeff: Float = 0.0
    
    public override init(sampleRate: Double = 44100.0) {
        super.init(sampleRate: sampleRate)
        updateCoefficients()
    }
    
    public func updateCoefficients() {
        releaseCoeff = expf(-1.0 / (Float(sampleRate) * release / 1000.0))
    }
    
    public override func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }
        
        updateCoefficients()
        let ceilingLinear = AudioUtils.dBToLinear(ceiling)
        var maxGR: Float = 0.0
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            let rightIdx = leftIdx + 1
            
            let left = buffer.samples[leftIdx]
            let right = buffer.channelCount > 1 ? buffer.samples[rightIdx] : left
            
            let peak = max(abs(left), abs(right))
            
            // Compute required gain
            var targetGain: Float = 1.0
            if peak > ceilingLinear {
                targetGain = ceilingLinear / peak
            }
            
            // Envelope follower (instant attack, smooth release)
            if targetGain < envelope {
                envelope = targetGain
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * targetGain
            }
            
            // Apply limiting
            buffer.samples[leftIdx] = left * envelope
            if buffer.channelCount > 1 {
                buffer.samples[rightIdx] = right * envelope
            }
            
            maxGR = min(maxGR, AudioUtils.linearToDB(envelope))
        }
        
        let smooth = expf(-Float(buffer.frameCount) / (Float(sampleRate) * 0.1))
        gainReduction = smooth * gainReduction + (1 - smooth) * (-maxGR)
    }
    
    public override func reset() {
        envelope = 1.0
        gainReduction = 0.0
    }
}
