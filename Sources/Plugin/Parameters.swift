#if os(macOS)
import AudioToolbox
import DSP
import ParameterAtomics

/// Addresses are part of the saved project/automation format; do not renumber them.
struct ParameterSpec {
    let address: AUParameterAddress
    let identifier: String
    let name: String
    let group: String
    let range: ClosedRange<Float>
    let initial: Float
    let unit: AudioUnitParameterUnit
    let apply: (PluginEngine, Float) -> Void

    init(_ address: AUParameterAddress, _ identifier: String, _ name: String,
         _ group: String, _ range: ClosedRange<Float>, _ initial: Float,
         _ unit: AudioUnitParameterUnit = .generic,
         apply: @escaping (PluginEngine, Float) -> Void) {
        self.address = address; self.identifier = identifier; self.name = name
        self.group = group; self.range = range; self.initial = initial
        self.unit = unit; self.apply = apply
    }

    func bounded(_ value: Float) -> Float {
        guard value.isFinite else { return initial }
        let clipped = min(range.upperBound, max(range.lowerBound, value))
        return unit == .boolean ? (clipped >= 0.5 ? 1 : 0) : clipped
    }

    static let groups = ["Main", "Equalizer", "Compressor", "Delay", "Reverb", "Limiter"]
    static let all: [ParameterSpec] = {
        var specs: [ParameterSpec] = [
            .init(0, "inputGain", "Input", "Main", -24...24, 0, .decibels) { $0.inputGain = $1 },
            .init(1, "outputGain", "Output", "Main", -24...24, 0, .decibels) { $0.outputGain = $1 },
            .init(2, "bypass", "Bypass", "Main", 0...1, 0, .boolean) { $0.isBypassed = $1 >= 0.5 },
            .init(10, "threshold", "Threshold", "Compressor", -60...0, -20, .decibels) { $0.compressor.threshold = $1 },
            .init(11, "ratio", "Ratio", "Compressor", 1...20, 4, .ratio) { $0.compressor.ratio = $1 },
            .init(12, "attack", "Attack", "Compressor", 0.1...100, 10, .milliseconds) { $0.compressor.attack = $1 },
            .init(13, "release", "Release", "Compressor", 10...1000, 100, .milliseconds) { $0.compressor.release = $1 },
            .init(14, "makeupGain", "Makeup", "Compressor", 0...24, 0, .decibels) { $0.compressor.makeupGain = $1 },
            .init(15, "compressorEnabled", "Enabled", "Compressor", 0...1, 1, .boolean) { $0.compressor.isEnabled = $1 >= 0.5 },
            .init(16, "knee", "Knee", "Compressor", 0...24, 6, .decibels) { $0.compressor.knee = $1 },
            .init(20, "roomSize", "Room size", "Reverb", 0...1, 0.5) { $0.reverb.roomSize = $1 },
            .init(21, "damping", "Damping", "Reverb", 0...1, 0.5) { $0.reverb.damping = $1 },
            .init(22, "reverbWet", "Wet", "Reverb", 0...1, 0.2) { $0.reverb.wetLevel = $1 },
            .init(23, "reverbDry", "Dry", "Reverb", 0...1, 1) { $0.reverb.dryLevel = $1 },
            .init(24, "reverbEnabled", "Enabled", "Reverb", 0...1, 1, .boolean) { $0.reverb.isEnabled = $1 >= 0.5 },
            .init(25, "width", "Width", "Reverb", 0...1, 1) { $0.reverb.width = $1 },
            .init(26, "preDelay", "Pre-delay", "Reverb", 0...199, 20, .milliseconds) { $0.reverb.preDelay = $1 },
            .init(30, "delayLeft", "Left time", "Delay", 1...1999, 250, .milliseconds) { $0.delay.delayTimeL = $1 },
            .init(31, "delayRight", "Right time", "Delay", 1...1999, 375, .milliseconds) { $0.delay.delayTimeR = $1 },
            .init(32, "feedback", "Feedback", "Delay", 0...0.95, 0.4) { $0.delay.feedback = $1 },
            .init(33, "delayWet", "Wet", "Delay", 0...1, 0.15) { $0.delay.wetLevel = $1 },
            .init(34, "delayDry", "Dry", "Delay", 0...1, 1) { $0.delay.dryLevel = $1 },
            .init(35, "delayEnabled", "Enabled", "Delay", 0...1, 1, .boolean) { $0.delay.isEnabled = $1 >= 0.5 },
            .init(36, "pingPong", "Ping-pong", "Delay", 0...1, 0, .boolean) { $0.delay.pingPong = $1 >= 0.5 },
            .init(37, "highCut", "High cut", "Delay", 500...20000, 8000, .hertz) { $0.delay.highCut = min($1, Float($0.sampleRate * 0.45)) },
            .init(38, "lowCut", "Low cut", "Delay", 20...2000, 100, .hertz) { $0.delay.lowCut = $1 },
            .init(40, "limiterEnabled", "Enabled", "Limiter", 0...1, 1, .boolean) { $0.limiter.isEnabled = $1 >= 0.5 },
            .init(41, "ceiling", "Ceiling", "Limiter", -24...0, -0.3, .decibels) { $0.limiter.ceiling = $1 },
            .init(42, "limiterRelease", "Release", "Limiter", 1...1000, 50, .milliseconds) { $0.limiter.release = $1 },
            .init(45, "eqEnabled", "Enabled", "Equalizer", 0...1, 1, .boolean) { $0.eq.isEnabled = $1 >= 0.5 }
        ]
        for (band, frequency) in [Float(80), 250, 1000, 4000, 12000].enumerated() {
            let base = AUParameterAddress(50 + band * 4)
            specs.append(.init(base, "eq\(band)Frequency", "Band \(band + 1) frequency", "Equalizer", 20...20000, frequency, .hertz) {
                $0.eq.bands[band].frequency = min($1, Float($0.sampleRate * 0.45))
            })
            specs.append(.init(base + 1, "eq\(band)Gain", "Band \(band + 1) gain", "Equalizer", -24...24, 0, .decibels) { $0.eq.bands[band].gain = $1 })
            specs.append(.init(base + 2, "eq\(band)Q", "Band \(band + 1) Q", "Equalizer", 0.1...10, 1) { $0.eq.bands[band].q = $1 })
            specs.append(.init(base + 3, "eq\(band)Enabled", "Band \(band + 1) enabled", "Equalizer", 0...1, 1, .boolean) { $0.eq.bands[band].isEnabled = $1 >= 0.5 })
        }
        return specs
    }()
}

/// UI/host and audio thread exchange scalar values without locks or sharing the DSP engine.
final class ParameterStore {
    private let pointer: OpaquePointer
    init() {
        guard let pointer = ParameterAtomicsCreate(128) else { fatalError("Parameter allocation failed") }
        self.pointer = pointer
        for spec in ParameterSpec.all { set(spec.address, spec.initial) }
    }
    deinit { ParameterAtomicsDestroy(pointer) }
    func get(_ address: AUParameterAddress) -> Float { ParameterAtomicsLoad(pointer, Int(address)) }
    func set(_ address: AUParameterAddress, _ value: Float) { ParameterAtomicsStore(pointer, Int(address), value) }
}
#endif
