// PluginEngine.swift
// Main plugin engine that combines all processors

import Foundation
#if canImport(Combine)
import Combine
#endif

/// Plugin preset data
public struct PluginPreset: Codable, Identifiable {
    public var id: UUID = UUID()
    public var name: String
    public var category: String
    public var eqSettings: EQPresetData
    public var compressorSettings: CompressorPresetData
    public var reverbSettings: ReverbPresetData
    public var delaySettings: DelayPresetData
    
    public init(name: String, category: String = "User") {
        self.name = name
        self.category = category
        self.eqSettings = EQPresetData()
        self.compressorSettings = CompressorPresetData()
        self.reverbSettings = ReverbPresetData()
        self.delaySettings = DelayPresetData()
    }
}

public struct EQPresetData: Codable {
    public var bands: [(frequency: Float, gain: Float, q: Float, type: String)] = []
    public var outputGain: Float = 0.0
    public var isEnabled: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case bands, outputGain, isEnabled
    }
    
    public init() {
        bands = [
            (80, 0, 1, "peak"),
            (250, 0, 1, "peak"),
            (1000, 0, 1, "peak"),
            (4000, 0, 1, "peak"),
            (12000, 0, 1, "peak")
        ]
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputGain = try container.decode(Float.self, forKey: .outputGain)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        // Simplified decoding for bands
        bands = []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outputGain, forKey: .outputGain)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

public struct CompressorPresetData: Codable {
    public var threshold: Float = -20.0
    public var ratio: Float = 4.0
    public var attack: Float = 10.0
    public var release: Float = 100.0
    public var makeupGain: Float = 0.0
    public var knee: Float = 6.0
    public var isEnabled: Bool = true
    
    public init() {}
}

public struct ReverbPresetData: Codable {
    public var roomSize: Float = 0.5
    public var damping: Float = 0.5
    public var width: Float = 1.0
    public var wetLevel: Float = 0.3
    public var dryLevel: Float = 0.7
    public var preDelay: Float = 20.0
    public var isEnabled: Bool = true
    
    public init() {}
}

public struct DelayPresetData: Codable {
    public var delayTimeL: Float = 250.0
    public var delayTimeR: Float = 250.0
    public var feedback: Float = 0.4
    public var wetLevel: Float = 0.3
    public var dryLevel: Float = 1.0
    public var pingPong: Bool = false
    public var isEnabled: Bool = true
    
    public init() {}
}

/// Main plugin engine
#if canImport(Combine)
public class PluginEngine: ObservableObject {
#else
public class PluginEngine {
#endif
    public var eq: ParametricEQ
    public var compressor: Compressor
    public var reverb: Reverb
    public var delay: StereoDelay
    public var limiter: Limiter
    
    public var inputGain: Float = 0.0    // dB
    public var outputGain: Float = 0.0   // dB
    public var isBypassed: Bool = false
    
    public var currentPreset: PluginPreset?
    public var presets: [PluginPreset] = []
    
    // Metering
    public var inputLevelL: Float = -60.0
    public var inputLevelR: Float = -60.0
    public var outputLevelL: Float = -60.0
    public var outputLevelR: Float = -60.0
    
    public var sampleRate: Double {
        didSet {
            eq.sampleRate = sampleRate
            compressor.sampleRate = sampleRate
            reverb.sampleRate = sampleRate
            delay.sampleRate = sampleRate
            limiter.sampleRate = sampleRate
        }
    }
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.eq = ParametricEQ(bandCount: 5, sampleRate: sampleRate)
        self.compressor = Compressor(sampleRate: sampleRate)
        self.reverb = Reverb(sampleRate: sampleRate)
        self.delay = StereoDelay(sampleRate: sampleRate)
        self.limiter = Limiter(sampleRate: sampleRate)
        
        loadFactoryPresets()
    }
    
    public func process(_ buffer: inout AudioBuffer) {
        guard !isBypassed else { return }
        
        // Apply input gain
        let inGainLinear = AudioUtils.dBToLinear(inputGain)
        for i in 0..<buffer.samples.count {
            buffer.samples[i] *= inGainLinear
        }
        
        // Update input meters
        updateInputMeters(buffer)
        
        // Process through effect chain
        eq.process(&buffer)
        compressor.process(&buffer)
        delay.process(&buffer)
        reverb.process(&buffer)
        
        // Apply output gain
        let outGainLinear = AudioUtils.dBToLinear(outputGain)
        for i in 0..<buffer.samples.count {
            buffer.samples[i] *= outGainLinear
        }
        
        // Final limiting
        limiter.process(&buffer)
        
        // Update output meters
        updateOutputMeters(buffer)
    }
    
    private func updateInputMeters(_ buffer: AudioBuffer) {
        var peakL: Float = 0.0
        var peakR: Float = 0.0
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            peakL = max(peakL, abs(buffer.samples[leftIdx]))
            if buffer.channelCount > 1 {
                peakR = max(peakR, abs(buffer.samples[leftIdx + 1]))
            }
        }
        
        let smooth: Float = 0.9
        inputLevelL = smooth * inputLevelL + (1.0 - smooth) * AudioUtils.linearToDB(peakL)
        inputLevelR = smooth * inputLevelR + (1.0 - smooth) * AudioUtils.linearToDB(peakR)
    }
    
    private func updateOutputMeters(_ buffer: AudioBuffer) {
        var peakL: Float = 0.0
        var peakR: Float = 0.0
        
        for frame in 0..<buffer.frameCount {
            let leftIdx = frame * buffer.channelCount
            peakL = max(peakL, abs(buffer.samples[leftIdx]))
            if buffer.channelCount > 1 {
                peakR = max(peakR, abs(buffer.samples[leftIdx + 1]))
            }
        }
        
        let smooth: Float = 0.9
        outputLevelL = smooth * outputLevelL + (1.0 - smooth) * AudioUtils.linearToDB(peakL)
        outputLevelR = smooth * outputLevelR + (1.0 - smooth) * AudioUtils.linearToDB(peakR)
    }
    
    public func reset() {
        eq.reset()
        compressor.reset()
        reverb.reset()
        delay.reset()
        limiter.reset()
    }
    
    private func loadFactoryPresets() {
        // Add some factory presets
        var warmVocal = PluginPreset(name: "Warm Vocal", category: "Vocal")
        warmVocal.compressorSettings.threshold = -18
        warmVocal.compressorSettings.ratio = 3
        warmVocal.reverbSettings.wetLevel = 0.2
        presets.append(warmVocal)
        
        var punchyDrums = PluginPreset(name: "Punchy Drums", category: "Drums")
        punchyDrums.compressorSettings.threshold = -15
        punchyDrums.compressorSettings.ratio = 6
        punchyDrums.compressorSettings.attack = 5
        presets.append(punchyDrums)
        
        var ambientPad = PluginPreset(name: "Ambient Pad", category: "Synth")
        ambientPad.reverbSettings.roomSize = 0.8
        ambientPad.reverbSettings.wetLevel = 0.5
        ambientPad.delaySettings.wetLevel = 0.3
        ambientPad.delaySettings.feedback = 0.5
        presets.append(ambientPad)
    }
    
    public func loadPreset(_ preset: PluginPreset) {
        currentPreset = preset
        
        // Apply compressor settings
        compressor.threshold = preset.compressorSettings.threshold
        compressor.ratio = preset.compressorSettings.ratio
        compressor.attack = preset.compressorSettings.attack
        compressor.release = preset.compressorSettings.release
        compressor.makeupGain = preset.compressorSettings.makeupGain
        compressor.isEnabled = preset.compressorSettings.isEnabled
        
        // Apply reverb settings
        reverb.roomSize = preset.reverbSettings.roomSize
        reverb.damping = preset.reverbSettings.damping
        reverb.width = preset.reverbSettings.width
        reverb.wetLevel = preset.reverbSettings.wetLevel
        reverb.dryLevel = preset.reverbSettings.dryLevel
        reverb.preDelay = preset.reverbSettings.preDelay
        reverb.isEnabled = preset.reverbSettings.isEnabled
        
        // Apply delay settings
        delay.delayTimeL = preset.delaySettings.delayTimeL
        delay.delayTimeR = preset.delaySettings.delayTimeR
        delay.feedback = preset.delaySettings.feedback
        delay.wetLevel = preset.delaySettings.wetLevel
        delay.dryLevel = preset.delaySettings.dryLevel
        delay.pingPong = preset.delaySettings.pingPong
        delay.isEnabled = preset.delaySettings.isEnabled
    }
    
    public func saveCurrentAsPreset(name: String, category: String = "User") -> PluginPreset {
        var preset = PluginPreset(name: name, category: category)
        
        // Save compressor settings
        preset.compressorSettings.threshold = compressor.threshold
        preset.compressorSettings.ratio = compressor.ratio
        preset.compressorSettings.attack = compressor.attack
        preset.compressorSettings.release = compressor.release
        preset.compressorSettings.makeupGain = compressor.makeupGain
        preset.compressorSettings.isEnabled = compressor.isEnabled
        
        // Save reverb settings
        preset.reverbSettings.roomSize = reverb.roomSize
        preset.reverbSettings.damping = reverb.damping
        preset.reverbSettings.width = reverb.width
        preset.reverbSettings.wetLevel = reverb.wetLevel
        preset.reverbSettings.dryLevel = reverb.dryLevel
        preset.reverbSettings.preDelay = reverb.preDelay
        preset.reverbSettings.isEnabled = reverb.isEnabled
        
        // Save delay settings
        preset.delaySettings.delayTimeL = delay.delayTimeL
        preset.delaySettings.delayTimeR = delay.delayTimeR
        preset.delaySettings.feedback = delay.feedback
        preset.delaySettings.wetLevel = delay.wetLevel
        preset.delaySettings.dryLevel = delay.dryLevel
        preset.delaySettings.pingPong = delay.pingPong
        preset.delaySettings.isEnabled = delay.isEnabled
        
        presets.append(preset)
        currentPreset = preset
        
        return preset
    }
}
