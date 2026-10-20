// Reverb.swift
// Algorithmic reverb implementation with Freeverb-style architecture

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Simple delay line
class DelayLine {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let size: Int
    
    init(size: Int) {
        self.size = size
        self.buffer = [Float](repeating: 0.0, count: size)
    }
    
    func write(_ sample: Float) {
        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % size
    }
    
    func read(delay: Int) -> Float {
        let readIndex = (writeIndex - delay + size) % size
        return buffer[readIndex]
    }
    
    func process(_ sample: Float) -> Float {
        let output = buffer[writeIndex]
        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % size
        return output
    }
    
    func clear() {
        for index in buffer.indices { buffer[index] = 0 }
        writeIndex = 0
    }
}

/// Comb filter for reverb
class CombFilter {
    private var delay: DelayLine
    private var feedback: Float
    private var damp: Float
    private var dampState: Float = 0.0
    
    init(size: Int, feedback: Float = 0.8, damp: Float = 0.2) {
        self.delay = DelayLine(size: size)
        self.feedback = feedback
        self.damp = damp
    }
    
    func setFeedback(_ fb: Float) {
        feedback = fb
    }
    
    func setDamp(_ d: Float) {
        damp = d
    }
    
    func process(_ input: Float) -> Float {
        let output = delay.process(input + dampState * feedback)
        dampState = output * (1.0 - damp) + dampState * damp
        return output
    }
    
    func clear() {
        delay.clear()
        dampState = 0.0
    }
}

/// All-pass filter for reverb diffusion
class AllPassFilter {
    private var delay: DelayLine
    private var feedback: Float
    
    init(size: Int, feedback: Float = 0.5) {
        self.delay = DelayLine(size: size)
        self.feedback = feedback
    }
    
    func process(_ input: Float) -> Float {
        let delayed = delay.read(delay: 0)
        let output = -input + delayed
        delay.write(input + delayed * feedback)
        return output
    }
    
    func clear() {
        delay.clear()
    }
}

/// Stereo reverb processor
public class Reverb: BaseAudioProcessor, PlatformObservable {
    // Parameters
    public var roomSize: Float = 0.5 {
        didSet { updateParameters() }
    }
    public var damping: Float = 0.5 {
        didSet { updateParameters() }
    }
    public var width: Float = 1.0
    public var wetLevel: Float = 0.3
    public var dryLevel: Float = 0.7
    public var preDelay: Float = 20.0  // ms
    
    // Internal components
    private var combsL: [CombFilter] = []
    private var combsR: [CombFilter] = []
    private var allpassL: [AllPassFilter] = []
    private var allpassR: [AllPassFilter] = []
    private var preDelayLine: DelayLine?
    
    // Freeverb-style tuning
    private let combTuning: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private let allpassTuning: [Int] = [556, 441, 341, 225]
    private let stereoSpread: Int = 23
    
    public override init(sampleRate: Double = 44100.0) {
        super.init(sampleRate: sampleRate)
        setupFilters()
    }
    
    private func setupFilters() {
        let scaleFactor = sampleRate / 44100.0
        
        // Create comb filters for left channel
        combsL = combTuning.map { size in
            CombFilter(size: Int(Double(size) * scaleFactor))
        }
        
        // Create comb filters for right channel (with stereo spread)
        combsR = combTuning.map { size in
            CombFilter(size: Int(Double(size + stereoSpread) * scaleFactor))
        }
        
        // Create allpass filters for left channel
        allpassL = allpassTuning.map { size in
            AllPassFilter(size: Int(Double(size) * scaleFactor))
        }
        
        // Create allpass filters for right channel
        allpassR = allpassTuning.map { size in
            AllPassFilter(size: Int(Double(size + stereoSpread) * scaleFactor))
        }
        
        // Pre-delay line (max 200ms)
        let preDelaySize = Int(sampleRate * 0.2)
        preDelayLine = DelayLine(size: preDelaySize)
        
        updateParameters()
    }
    
    private func updateParameters() {
        let feedback = roomSize * 0.28 + 0.7
        let damp = damping
        
        for comb in combsL {
            comb.setFeedback(feedback)
            comb.setDamp(damp)
        }
        for comb in combsR {
            comb.setFeedback(feedback)
            comb.setDamp(damp)
        }
    }
    
    public override func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }
        
        let preDelaySamples = Int(preDelay * Float(sampleRate) / 1000.0)
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            let rightIdx = leftIdx + 1
            
            let left = buffer.samples[leftIdx]
            let right = buffer.channelCount > 1 ? buffer.samples[rightIdx] : left
            
            // Mix to mono for reverb input and apply pre-delay
            let input = (left + right) * 0.5
            preDelayLine?.write(input)
            let delayedInput = preDelayLine?.read(delay: preDelaySamples) ?? input
            
            // Process through comb filters (parallel)
            var outL: Float = 0.0
            var outR: Float = 0.0
            
            for i in 0..<combsL.count {
                outL += combsL[i].process(delayedInput)
                outR += combsR[i].process(delayedInput)
            }
            
            // Process through allpass filters (series)
            for allpass in allpassL {
                outL = allpass.process(outL)
            }
            for allpass in allpassR {
                outR = allpass.process(outR)
            }
            
            // Apply stereo width
            let wet1 = (1.0 + width) * 0.5
            let wet2 = (1.0 - width) * 0.5
            let wetL = outL * wet1 + outR * wet2
            let wetR = outR * wet1 + outL * wet2
            
            // Mix dry and wet
            buffer.samples[leftIdx] = left * dryLevel + wetL * wetLevel
            if buffer.channelCount > 1 {
                buffer.samples[rightIdx] = right * dryLevel + wetR * wetLevel
            }
        }
    }
    
    public override func reset() {
        for comb in combsL { comb.clear() }
        for comb in combsR { comb.clear() }
        for allpass in allpassL { allpass.clear() }
        for allpass in allpassR { allpass.clear() }
        preDelayLine?.clear()
    }
}
