#if os(macOS)
import AudioToolbox
import AVFoundation
import DSP

public enum SwiftAudioPluginFactory {
    public static var componentDescription: AudioComponentDescription {
        AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                  componentSubType: 0x73776674, // swft
                                  componentManufacturer: 0x4f6c6976, // Oliv
                                  componentFlags: 0, componentFlagsMask: 0)
    }
    public static func registerAudioUnit() {
        AUAudioUnit.registerSubclass(SwiftAudioUnit.self, as: componentDescription,
                                     name: "OliverJ: Swift Audio Plugin", version: 0x10000)
    }
}

/// Display-only readings, in dBFS (levels) and dB (gain reduction).
/// Each scalar is atomic; UI polling never touches the render-owned engine.
public struct MeterSnapshot {
    public let inputLeft: Float
    public let inputRight: Float
    public let outputLeft: Float
    public let outputRight: Float
    public let compressorReduction: Float
    public let limiterReduction: Float
}

public final class SwiftAudioUnit: AUAudioUnit {
    private let values = ParameterStore()
    private let meters = ParameterStore()
    public var meterSnapshot: MeterSnapshot {
        MeterSnapshot(inputLeft: meters.get(90), inputRight: meters.get(91),
                      outputLeft: meters.get(92), outputRight: meters.get(93),
                      compressorReduction: meters.get(94), limiterReduction: meters.get(95))
    }
    private func clearMeters() {
        for address: AUParameterAddress in 90...93 { meters.set(address, -100) }
        meters.set(94, 0); meters.set(95, 0)
    }
    private var inputs: AUAudioUnitBusArray!
    private var outputs: AUAudioUnitBusArray!
    private var tree: AUParameterTree!
    private let resources = RenderResources()
    private var selectedPreset: AUAudioUnitPreset?

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let input = try AUAudioUnitBus(format: format)
        let output = try AUAudioUnitBus(format: format)
        input.supportedChannelCounts = [1, 2]
        output.supportedChannelCounts = [1, 2]
        inputs = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [input])
        outputs = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [output])
        maximumFramesToRender = 4096
        let groups = ParameterSpec.groups.map { group in
            AUParameterTree.createGroup(withIdentifier: group.lowercased(), name: group,
                children: ParameterSpec.all.filter { $0.group == group }.map { spec in
                    AUParameterTree.createParameter(withIdentifier: spec.identifier, name: spec.name,
                        address: spec.address, min: spec.range.lowerBound, max: spec.range.upperBound,
                        unit: spec.unit, unitName: nil,
                        flags: [.flag_IsReadable, .flag_IsWritable],
                        valueStrings: nil, dependentParameters: nil)
                })
        }
        tree = AUParameterTree.createTree(withChildren: groups)
        for spec in ParameterSpec.all { tree.parameter(withAddress: spec.address)?.value = spec.initial }
        let store = values
        tree.implementorValueObserver = { parameter, value in
            guard let spec = ParameterSpec.all.first(where: { $0.address == parameter.address }) else { return }
            store.set(spec.address, spec.bounded(value))
        }
        tree.implementorValueProvider = { parameter in store.get(parameter.address) }
        selectedPreset = factoryPresets?.first
        clearMeters()
    }

    public override var parameterTree: AUParameterTree? {
        get { tree }
        set { /* This unit has a fixed, versioned parameter layout. */ }
    }
    public override var inputBusses: AUAudioUnitBusArray { inputs }
    public override var outputBusses: AUAudioUnitBusArray { outputs }
    public override var channelCapabilities: [NSNumber]? { [1, 1, 2, 2] }
    public override var canProcessInPlace: Bool { false }
    public override var latency: TimeInterval { 0 }
    /// Locked room tuning: RenderState applies it and tailTime reports it.
    static let roomSize: Float = 0.68
    static let roomPreDelayMilliseconds: Float = 24

    public override var tailTime: TimeInterval {
        guard !shouldBypassEffect, values.get(3) > 0 else { return 0 }
        // Only Amount, gain and bypass reach the engine, so the tail is always
        // this locked room decay.
        let sampleRate = outputs?[0].format.sampleRate ?? 44100
        return Reverb.estimatedTailSeconds(roomSize: Self.roomSize,
                                           preDelayMilliseconds: Self.roomPreDelayMilliseconds,
                                           sampleRate: sampleRate)
    }
    public override var shouldBypassEffect: Bool {
        get { values.get(2) >= 0.5 }
        set { tree.parameter(withAddress: 2)?.value = newValue ? 1 : 0 }
    }

    public override func allocateRenderResources() throws {
        let format = outputs[0].format
        guard format == inputs[0].format, format.commonFormat == .pcmFormatFloat32,
              !format.isInterleaved, (1...2).contains(format.channelCount),
              (8000...192000).contains(format.sampleRate), maximumFramesToRender > 0 else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        let state = try RenderState(format: format, capacity: maximumFramesToRender, values: values, meters: meters)
        try super.allocateRenderResources()
        resources.state = state
    }
    public override func deallocateRenderResources() {
        resources.state = nil
        clearMeters()
        super.deallocateRenderResources()
    }
    public override func reset() {
        super.reset()
        resources.state?.reset()
        clearMeters()
    }

    public override var factoryPresets: [AUAudioUnitPreset]? {
        ["Classical Room"].enumerated().map { index, name in
            let preset = AUAudioUnitPreset()
            preset.number = index
            preset.name = name
            return preset
        }
    }
    public override var currentPreset: AUAudioUnitPreset? {
        get { selectedPreset }
        set {
            guard let preset = newValue else { selectedPreset = nil; return }
            if preset.number >= 0 {
                guard preset.number < 1 else { return }
                for spec in ParameterSpec.all { tree.parameter(withAddress: spec.address)?.value = spec.initial }
                let overrides: [AUParameterAddress: Float]
                switch preset.number {
                default: overrides = [:]
                }
                for (address, value) in overrides { tree.parameter(withAddress: address)?.value = value }
            }
            selectedPreset = preset
        }
    }

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state["SwiftAudioPluginStateVersion"] = 1
            state["SwiftAudioPluginParameters"] = Dictionary(uniqueKeysWithValues:
                ParameterSpec.all.map { ($0.identifier, values.get($0.address)) })
            return state
        }
        set {
            guard let state = newValue,
                  let version = state["SwiftAudioPluginStateVersion"] as? Int, version == 1,
                  let parameters = state["SwiftAudioPluginParameters"] as? [String: NSNumber] else { return }
            super.fullState = state
            for spec in ParameterSpec.all {
                if let value = parameters[spec.identifier]?.floatValue, value.isFinite {
                    tree.parameter(withAddress: spec.address)?.value = spec.bounded(value)
                }
            }
        }
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        // Hosts may cache this block before allocating resources (including AUHostingService).
        let resources = self.resources
        return { flags, timestamp, frameCount, bus, output, events, pull in
            guard let state = resources.state else { return kAudioUnitErr_Uninitialized }
            guard bus == 0 else { return kAudioUnitErr_InvalidElement }
            guard frameCount <= state.capacity else { return kAudioUnitErr_TooManyFramesToProcess }
            guard let pull else { return kAudioUnitErr_NoConnection }
            let buffers = UnsafeMutableAudioBufferListPointer(output)
            guard buffers.count == state.channels else { return kAudioUnitErr_FormatNotSupported }
            for channel in 0..<state.channels {
                guard buffers[channel].mNumberChannels == 1 else { return kAudioUnitErr_FormatNotSupported }
                if buffers[channel].mData == nil {
                    buffers[channel].mData = UnsafeMutableRawPointer(state.output.floatChannelData![channel])
                } else if buffers[channel].mDataByteSize < frameCount * 4 {
                    return kAudio_ParamError
                }
                buffers[channel].mDataByteSize = frameCount * 4
            }
            // Restore our owned pointers: an upstream AU is allowed to substitute its own buffers.
            state.input.frameLength = frameCount
            let inputBuffers = UnsafeMutableAudioBufferListPointer(state.input.mutableAudioBufferList)
            for channel in 0..<state.channels {
                inputBuffers[channel].mData = UnsafeMutableRawPointer(state.inputPointers[channel])
                inputBuffers[channel].mDataByteSize = frameCount * 4
            }
            var inputFlags = AudioUnitRenderActionFlags()
            let status = pull(&inputFlags, timestamp, frameCount, 0, inputBuffers.unsafeMutablePointer)
            guard status == noErr else { return status }
            for channel in 0..<state.channels {
                guard inputBuffers[channel].mData != nil,
                      inputBuffers[channel].mDataByteSize >= frameCount * 4 else { return kAudio_ParamError }
            }
            state.syncParameters()
            var event = events
            var position = 0
            let total = Int(frameCount)
            let start = AUEventSampleTime(timestamp.pointee.mSampleTime)
            while position < total {
                // Events are sorted by the host. Negative/immediate/past events apply at block start.
                while let current = event, current.pointee.head.eventSampleTime <= start + Int64(position) {
                    if current.pointee.head.eventType == .parameter || current.pointee.head.eventType == .parameterRamp {
                        state.applyEvent(current.pointee.parameter)
                    }
                    event = UnsafePointer(current.pointee.head.next)
                }
                let next = event.map { min(total, max(position, Int($0.pointee.head.eventSampleTime - start))) } ?? total
                let count = state.hasRamps ? 1 : max(1, next - position)
                state.process(input: inputBuffers, output: buffers, offset: position, count: min(count, total - position))
                position += min(count, total - position)
            }
            state.publishMeters()
            // A reverb/delay tail may produce output even when upstream reports silence.
            flags.pointee.remove(.unitRenderAction_OutputIsSilence)
            return noErr
        }
    }
}

/// Resource changes are serialized against rendering by the AU allocation contract.
private final class RenderResources {
    var state: RenderState?
}

/// The engine and all scratch memory belong exclusively to the render thread after allocation.
private final class RenderState {
    let engine: PluginEngine
    let input: AVAudioPCMBuffer
    let output: AVAudioPCMBuffer
    let inputPointers: [UnsafeMutablePointer<Float>]
    let channels: Int
    let capacity: AUAudioFrameCount
    let values: ParameterStore
    let meters: ParameterStore
    var scratch: DSP.AudioBuffer
    var applied = [Float](repeating: .nan, count: 128)
    var rampRemaining = [UInt32](repeating: 0, count: 128)
    var rampStep = [Float](repeating: 0, count: 128)
    var hasRamps = false

    init(format: AVAudioFormat, capacity: AUAudioFrameCount, values: ParameterStore, meters: ParameterStore) throws {
        guard let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization))
        }
        self.input = input; self.output = output; self.capacity = capacity; self.values = values; self.meters = meters
        channels = Int(format.channelCount)
        inputPointers = (0..<Int(format.channelCount)).map { input.floatChannelData![$0] }
        scratch = DSP.AudioBuffer(frameCount: Int(capacity), channelCount: Int(format.channelCount))
        // Delay/reverb storage is sized in their initializers at the actual negotiated rate.
        engine = PluginEngine(sampleRate: format.sampleRate)
        engine.roomReverbMode = true
        engine.eq.isEnabled = false
        engine.compressor.isEnabled = false
        engine.delay.isEnabled = false
        engine.limiter.isEnabled = true
        engine.reverb.isEnabled = true
        engine.reverb.roomSize = SwiftAudioUnit.roomSize
        engine.reverb.damping = 0.62
        engine.reverb.width = 0.82
        engine.reverb.preDelay = SwiftAudioUnit.roomPreDelayMilliseconds
        engine.reverb.dryLevel = 1
        engine.reverb.wetLevel = 0.0062 * values.get(3)
        syncParameters()
    }
    func publishMeters() {
        meters.set(90, engine.inputLevelL); meters.set(91, engine.inputLevelR)
        meters.set(92, engine.outputLevelL); meters.set(93, engine.outputLevelR)
        meters.set(94, !engine.isBypassed && engine.compressor.isEnabled ? engine.compressor.gainReduction : 0)
        meters.set(95, !engine.isBypassed && engine.limiter.isEnabled ? engine.limiter.gainReduction : 0)
    }
    func syncParameters() {
        for spec in ParameterSpec.all {
            // Keep the former channel-strip addresses in saved host projects, but
            // only expose gain, bypass and reverb Amount to the new sound engine.
            guard [AUParameterAddress(0), 1, 2, 3].contains(spec.address) else { continue }
            let index = Int(spec.address), value = values.get(spec.address)
            if rampRemaining[index] == 0 && applied[index] != value {
                spec.apply(engine, value); applied[index] = value
            }
        }
    }
    func applyEvent(_ event: AUParameterEvent) {
        guard let spec = ParameterSpec.all.first(where: { $0.address == event.parameterAddress }) else { return }
        guard [AUParameterAddress(0), 1, 2, 3].contains(spec.address) else { return }
        let index = Int(spec.address), target = spec.bounded(event.value)
        values.set(spec.address, target)
        if event.eventType == .parameterRamp && event.rampDurationSampleFrames > 0 && spec.unit != .boolean {
            rampRemaining[index] = event.rampDurationSampleFrames
            rampStep[index] = (target - applied[index]) / Float(event.rampDurationSampleFrames)
            hasRamps = true
        } else {
            rampRemaining[index] = 0
            applied[index] = target
            spec.apply(engine, target)
        }
    }
    func reset() {
        engine.reset()
        for index in rampRemaining.indices { rampRemaining[index] = 0 }
        hasRamps = false
        syncParameters()
    }
    func process(input: UnsafeMutableAudioBufferListPointer, output: UnsafeMutableAudioBufferListPointer,
                 offset: Int, count: Int) {
        scratch.frameCount = count
        for channel in 0..<channels {
            let source = input[channel].mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<count { scratch.samples[frame * channels + channel] = source[offset + frame] }
        }
        engine.process(&scratch)
        for channel in 0..<channels {
            let destination = output[channel].mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<count { destination[offset + frame] = scratch.samples[frame * channels + channel] }
        }
        if hasRamps {
            hasRamps = false
            for spec in ParameterSpec.all {
                let index = Int(spec.address)
                if rampRemaining[index] > 0 {
                    rampRemaining[index] -= 1
                    applied[index] = rampRemaining[index] == 0 ? values.get(spec.address) : applied[index] + rampStep[index]
                    spec.apply(engine, applied[index])
                    hasRamps = hasRamps || rampRemaining[index] > 0
                }
            }
        }
    }
}
#endif
