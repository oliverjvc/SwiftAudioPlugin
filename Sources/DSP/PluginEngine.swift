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
    public var limiterSettings: LimiterPresetData = LimiterPresetData()
    public var inputGain: Float = 0.0
    public var outputGain: Float = 0.0

    enum CodingKeys: String, CodingKey {
        case id, name, category, eqSettings, compressorSettings, reverbSettings, delaySettings
        case limiterSettings, inputGain, outputGain
    }
    
    public init(name: String, category: String = "User") {
        self.name = name
        self.category = category
        self.eqSettings = EQPresetData()
        self.compressorSettings = CompressorPresetData()
        self.reverbSettings = ReverbPresetData()
        self.delaySettings = DelayPresetData()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        eqSettings = try container.decode(EQPresetData.self, forKey: .eqSettings)
        compressorSettings = try container.decode(CompressorPresetData.self, forKey: .compressorSettings)
        reverbSettings = try container.decode(ReverbPresetData.self, forKey: .reverbSettings)
        delaySettings = try container.decode(DelayPresetData.self, forKey: .delaySettings)
        // Presets written before these fields existed use the processor defaults.
        limiterSettings = try container.decodeIfPresent(LimiterPresetData.self, forKey: .limiterSettings)
            ?? LimiterPresetData()
        inputGain = try container.decodeIfPresent(Float.self, forKey: .inputGain) ?? 0.0
        outputGain = try container.decodeIfPresent(Float.self, forKey: .outputGain) ?? 0.0
    }
}

public struct EQPresetData: Codable {
    public var bands: [(frequency: Float, gain: Float, q: Float, type: String)] = []
    /// Indexed alongside bands to preserve the existing public tuple API.
    /// Missing entries mean enabled; extra entries are ignored.
    public var bandEnabled: [Bool] = []
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
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputGain = try container.decode(Float.self, forKey: .outputGain)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        // The original encoder omitted bands entirely. Restore the neutral five-band EQ.
        if let decoded = try container.decodeIfPresent([BandData].self, forKey: .bands) {
            bands = decoded.map { ($0.frequency, $0.gain, $0.q, $0.type) }
            bandEnabled = decoded.map { $0.isEnabled }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outputGain, forKey: .outputGain)
        try container.encode(isEnabled, forKey: .isEnabled)
        let encoded = bands.enumerated().map { index, band in
            BandData(frequency: band.frequency, gain: band.gain, q: band.q, type: band.type,
                     isEnabled: index < bandEnabled.count ? bandEnabled[index] : true)
        }
        try container.encode(encoded, forKey: .bands)
    }

    private struct BandData: Codable {
        var frequency: Float
        var gain: Float
        var q: Float
        var type: String
        var isEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case frequency, gain, q, type, isEnabled
        }

        init(frequency: Float, gain: Float, q: Float, type: String, isEnabled: Bool) {
            self.frequency = frequency
            self.gain = gain
            self.q = q
            self.type = type
            self.isEnabled = isEnabled
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            frequency = try container.decode(Float.self, forKey: .frequency)
            gain = try container.decode(Float.self, forKey: .gain)
            q = try container.decode(Float.self, forKey: .q)
            type = try container.decode(String.self, forKey: .type)
            isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        }
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
    public var highCut: Float = 8000.0
    public var lowCut: Float = 100.0
    public var tempo: Float = 120.0
    public var syncEnabled: Bool = false
    public var syncDivisionL: Float = 0.25
    public var syncDivisionR: Float = 0.25

    enum CodingKeys: String, CodingKey {
        case delayTimeL, delayTimeR, feedback, wetLevel, dryLevel, pingPong, isEnabled
        case highCut, lowCut, tempo, syncEnabled, syncDivisionL, syncDivisionR
    }
    
    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delayTimeL = try container.decode(Float.self, forKey: .delayTimeL)
        delayTimeR = try container.decode(Float.self, forKey: .delayTimeR)
        feedback = try container.decode(Float.self, forKey: .feedback)
        wetLevel = try container.decode(Float.self, forKey: .wetLevel)
        dryLevel = try container.decode(Float.self, forKey: .dryLevel)
        pingPong = try container.decode(Bool.self, forKey: .pingPong)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        highCut = try container.decodeIfPresent(Float.self, forKey: .highCut) ?? 8000.0
        lowCut = try container.decodeIfPresent(Float.self, forKey: .lowCut) ?? 100.0
        tempo = try container.decodeIfPresent(Float.self, forKey: .tempo) ?? 120.0
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
        syncDivisionL = try container.decodeIfPresent(Float.self, forKey: .syncDivisionL) ?? 0.25
        syncDivisionR = try container.decodeIfPresent(Float.self, forKey: .syncDivisionR) ?? 0.25
    }
}

public struct LimiterPresetData: Codable {
    public var ceiling: Float = -0.3
    public var release: Float = 50.0
    public var isEnabled: Bool = true

    public init() {}
}

/// Main plugin engine
public class PluginEngine: PlatformObservable {
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
        for i in 0..<(buffer.frameCount * buffer.channelCount) {
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
        for i in 0..<(buffer.frameCount * buffer.channelCount) {
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

        inputGain = preset.inputGain
        outputGain = preset.outputGain

        // Reuse existing bands so UI references and filter history remain intact.
        eq.bands = preset.eqSettings.bands.enumerated().map { index, settings in
            let band = index < eq.bands.count ? eq.bands[index] : EQBand()
            band.frequency = settings.frequency
            band.gain = settings.gain
            band.q = settings.q
            // Accept the original lowercase "peak" spelling as well as enum raw values.
            // Unknown types fall back to a peak filter.
            band.type = EQBandType.allCases.first {
                $0.rawValue.lowercased() == settings.type.lowercased()
            } ?? .peak
            band.isEnabled = index < preset.eqSettings.bandEnabled.count
                ? preset.eqSettings.bandEnabled[index] : true
            band.setSampleRate(sampleRate)
            return band
        }
        eq.outputGain = preset.eqSettings.outputGain
        eq.isEnabled = preset.eqSettings.isEnabled
        
        // Apply compressor settings
        compressor.threshold = preset.compressorSettings.threshold
        compressor.ratio = preset.compressorSettings.ratio
        compressor.attack = preset.compressorSettings.attack
        compressor.release = preset.compressorSettings.release
        compressor.makeupGain = preset.compressorSettings.makeupGain
        compressor.knee = preset.compressorSettings.knee
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
        delay.highCut = preset.delaySettings.highCut
        delay.lowCut = preset.delaySettings.lowCut
        delay.tempo = preset.delaySettings.tempo
        delay.syncEnabled = preset.delaySettings.syncEnabled
        delay.syncDivisionL = preset.delaySettings.syncDivisionL
        delay.syncDivisionR = preset.delaySettings.syncDivisionR

        limiter.ceiling = preset.limiterSettings.ceiling
        limiter.release = preset.limiterSettings.release
        limiter.isEnabled = preset.limiterSettings.isEnabled
    }
    
    public func saveCurrentAsPreset(name: String, category: String = "User") -> PluginPreset {
        var preset = PluginPreset(name: name, category: category)

        // Sample rate, global bypass, meters and DSP history are runtime state.
        preset.inputGain = inputGain
        preset.outputGain = outputGain
        preset.eqSettings.bands = eq.bands.map { ($0.frequency, $0.gain, $0.q, $0.type.rawValue) }
        preset.eqSettings.bandEnabled = eq.bands.map { $0.isEnabled }
        preset.eqSettings.outputGain = eq.outputGain
        preset.eqSettings.isEnabled = eq.isEnabled
        
        // Save compressor settings
        preset.compressorSettings.threshold = compressor.threshold
        preset.compressorSettings.ratio = compressor.ratio
        preset.compressorSettings.attack = compressor.attack
        preset.compressorSettings.release = compressor.release
        preset.compressorSettings.makeupGain = compressor.makeupGain
        preset.compressorSettings.knee = compressor.knee
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
        preset.delaySettings.highCut = delay.highCut
        preset.delaySettings.lowCut = delay.lowCut
        preset.delaySettings.tempo = delay.tempo
        preset.delaySettings.syncEnabled = delay.syncEnabled
        preset.delaySettings.syncDivisionL = delay.syncDivisionL
        preset.delaySettings.syncDivisionR = delay.syncDivisionR

        preset.limiterSettings.ceiling = limiter.ceiling
        preset.limiterSettings.release = limiter.release
        preset.limiterSettings.isEnabled = limiter.isEnabled
        
        presets.append(preset)
        currentPreset = preset
        
        return preset
    }
}
