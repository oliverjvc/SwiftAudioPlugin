// AudioProcessor.swift
// Core audio processing protocol and base implementation

import Foundation

/// Sample rate commonly used in audio processing
public enum SampleRate: Double {
    case rate44100 = 44100.0
    case rate48000 = 48000.0
    case rate96000 = 96000.0
    case rate192000 = 192000.0
}

/// Audio buffer for processing
public struct AudioBuffer {
    public var samples: [Float]
    public var channelCount: Int
    public var frameCount: Int
    
    public init(samples: [Float], channelCount: Int) {
        self.samples = samples
        self.channelCount = channelCount
        self.frameCount = samples.count / channelCount
    }
    
    public init(frameCount: Int, channelCount: Int) {
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.samples = [Float](repeating: 0.0, count: frameCount * channelCount)
    }
}

/// Protocol for all audio processors
public protocol AudioProcessor {
    var sampleRate: Double { get set }
    var isEnabled: Bool { get set }
    
    func process(_ buffer: inout AudioBuffer)
    func reset()
}

/// Base class for audio processors with common functionality
open class BaseAudioProcessor: AudioProcessor {
    public var sampleRate: Double
    public var isEnabled: Bool = true
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    open func process(_ buffer: inout AudioBuffer) {
        // Override in subclass
    }
    
    open func reset() {
        // Override in subclass
    }
}

/// Utility functions for audio processing
public struct AudioUtils {
    /// Convert decibels to linear gain
    public static func dBToLinear(_ dB: Float) -> Float {
        return powf(10.0, dB / 20.0)
    }
    
    /// Convert linear gain to decibels
    public static func linearToDB(_ linear: Float) -> Float {
        if linear <= 0 { return -100.0 }
        return 20.0 * log10f(linear)
    }
    
    /// Soft clipping function
    public static func softClip(_ sample: Float, threshold: Float = 0.9) -> Float {
        if abs(sample) <= threshold {
            return sample
        }
        let sign: Float = sample > 0 ? 1.0 : -1.0
        let excess = abs(sample) - threshold
        let clipped = threshold + (1.0 - threshold) * tanhf(excess / (1.0 - threshold))
        return sign * clipped
    }
}
