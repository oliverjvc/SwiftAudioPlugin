// Equalizer.swift
// Professional parametric EQ implementation

import Foundation
#if canImport(Combine)
import Combine
#endif

/// EQ band type
public enum EQBandType: String, CaseIterable, Codable {
    case lowShelf = "Low Shelf"
    case highShelf = "High Shelf"
    case peak = "Peak"
    case lowPass = "Low Pass"
    case highPass = "High Pass"
    case notch = "Notch"
}

/// Single EQ band with biquad filter
public class EQBand: PlatformObservable {
    public var frequency: Float = 1000.0  // Hz
    public var gain: Float = 0.0          // dB
    public var q: Float = 1.0             // Q factor
    public var type: EQBandType = .peak
    public var isEnabled: Bool = true
    
    // Biquad filter coefficients
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0
    
    // Filter state (stereo)
    private var x1L: Float = 0.0, x2L: Float = 0.0
    private var y1L: Float = 0.0, y2L: Float = 0.0
    private var x1R: Float = 0.0, x2R: Float = 0.0
    private var y1R: Float = 0.0, y2R: Float = 0.0
    
    private var sampleRate: Double = 44100.0
    
    public init(frequency: Float = 1000.0, gain: Float = 0.0, q: Float = 1.0, type: EQBandType = .peak) {
        self.frequency = frequency
        self.gain = gain
        self.q = q
        self.type = type
    }
    
    public func setSampleRate(_ rate: Double) {
        sampleRate = rate
        updateCoefficients()
    }
    
    public func updateCoefficients() {
        let omega = 2.0 * Float.pi * frequency / Float(sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = powf(10.0, gain / 40.0)
        
        var a0: Float = 1.0
        
        switch type {
        case .peak:
            b0 = 1.0 + alpha * A
            b1 = -2.0 * cosOmega
            b2 = 1.0 - alpha * A
            a0 = 1.0 + alpha / A
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha / A
            
        case .lowShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha)
            b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega)
            b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha)
            a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
            a1 = -2 * ((A - 1) + (A + 1) * cosOmega)
            a2 = (A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha
            
        case .highShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha)
            b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega)
            b2 = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha)
            a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha
            a1 = 2 * ((A - 1) - (A + 1) * cosOmega)
            a2 = (A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha
            
        case .lowPass:
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
            
        case .highPass:
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
            
        case .notch:
            b0 = 1.0
            b1 = -2.0 * cosOmega
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
        }
        
        // Normalize coefficients
        b0 /= a0
        b1 /= a0
        b2 /= a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }
    
    public func processSample(left: Float, right: Float) -> (Float, Float) {
        guard isEnabled else { return (left, right) }
        
        // Process left channel
        let outL = b0 * left + b1 * x1L + b2 * x2L - a1 * y1L - a2 * y2L
        x2L = x1L
        x1L = left
        y2L = y1L
        y1L = outL
        
        // Process right channel
        let outR = b0 * right + b1 * x1R + b2 * x2R - a1 * y1R - a2 * y2R
        x2R = x1R
        x1R = right
        y2R = y1R
        y1R = outR
        
        return (outL, outR)
    }
    
    public func reset() {
        x1L = 0; x2L = 0; y1L = 0; y2L = 0
        x1R = 0; x2R = 0; y1R = 0; y2R = 0
    }
}

/// Multi-band parametric equalizer
public class ParametricEQ: BaseAudioProcessor, PlatformObservable {
    public var bands: [EQBand]
    public var outputGain: Float = 0.0  // dB
    
    public init(bandCount: Int = 5, sampleRate: Double = 44100.0) {
        // Default frequency distribution
        let defaultFreqs: [Float] = [80, 250, 1000, 4000, 12000]
        
        self.bands = (0..<bandCount).map { i in
            let freq = i < defaultFreqs.count ? defaultFreqs[i] : 1000.0
            return EQBand(frequency: freq)
        }
        
        super.init(sampleRate: sampleRate)
        
        for band in bands {
            band.setSampleRate(sampleRate)
        }
    }
    
    public override func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }
        
        let linearGain = AudioUtils.dBToLinear(outputGain)
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            let rightIdx = leftIdx + 1
            
            var left = buffer.samples[leftIdx]
            var right = buffer.channelCount > 1 ? buffer.samples[rightIdx] : left
            
            // Process through each band
            for band in bands {
                (left, right) = band.processSample(left: left, right: right)
            }
            
            // Apply output gain
            buffer.samples[leftIdx] = left * linearGain
            if buffer.channelCount > 1 {
                buffer.samples[rightIdx] = right * linearGain
            }
        }
    }
    
    public override func reset() {
        for band in bands {
            band.reset()
        }
    }
}
