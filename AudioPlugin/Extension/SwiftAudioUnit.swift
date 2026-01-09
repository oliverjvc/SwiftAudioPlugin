import AudioToolbox
import AVFoundation

public class SwiftAudioUnit: AUAudioUnit {
    
    // MARK: - Properties
    
    private let engine = PluginEngine(sampleRate: 44100.0)
    
    private var _parameterTree: AUParameterTree?
    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!
    
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    
    // Parameter addresses
    private enum ParameterAddress: AUParameterAddress {
        case eqLowGain = 0
        case eqMidGain = 1
        case eqHighGain = 2
        case compThreshold = 10
        case compRatio = 11
        case compAttack = 12
        case compRelease = 13
        case reverbSize = 20
        case reverbDamping = 21
        case reverbMix = 22
        case delayTime = 30
        case delayFeedback = 31
        case delayMix = 32
        case inputGain = 100
        case outputGain = 101
    }
    
    // MARK: - Initialization
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)
        
        // Setup format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        
        // Create buses
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        
        _inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        
        // Setup parameters
        setupParameterTree()
    }
    
    private func setupParameterTree() {
        // EQ Parameters
        let eqLowGain = AUParameterTree.createParameter(
            withIdentifier: "eqLowGain",
            name: "Low Gain",
            address: ParameterAddress.eqLowGain.rawValue,
            min: -12.0, max: 12.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        eqLowGain.value = 0.0
        
        let eqMidGain = AUParameterTree.createParameter(
            withIdentifier: "eqMidGain",
            name: "Mid Gain",
            address: ParameterAddress.eqMidGain.rawValue,
            min: -12.0, max: 12.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        eqMidGain.value = 0.0
        
        let eqHighGain = AUParameterTree.createParameter(
            withIdentifier: "eqHighGain",
            name: "High Gain",
            address: ParameterAddress.eqHighGain.rawValue,
            min: -12.0, max: 12.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        eqHighGain.value = 0.0
        
        // Compressor Parameters
        let compThreshold = AUParameterTree.createParameter(
            withIdentifier: "compThreshold",
            name: "Threshold",
            address: ParameterAddress.compThreshold.rawValue,
            min: -60.0, max: 0.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        compThreshold.value = -20.0
        
        let compRatio = AUParameterTree.createParameter(
            withIdentifier: "compRatio",
            name: "Ratio",
            address: ParameterAddress.compRatio.rawValue,
            min: 1.0, max: 20.0,
            unit: .ratio,
            unitName: ":1",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        compRatio.value = 4.0
        
        let compAttack = AUParameterTree.createParameter(
            withIdentifier: "compAttack",
            name: "Attack",
            address: ParameterAddress.compAttack.rawValue,
            min: 0.1, max: 100.0,
            unit: .milliseconds,
            unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        compAttack.value = 10.0
        
        let compRelease = AUParameterTree.createParameter(
            withIdentifier: "compRelease",
            name: "Release",
            address: ParameterAddress.compRelease.rawValue,
            min: 10.0, max: 1000.0,
            unit: .milliseconds,
            unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        compRelease.value = 100.0
        
        // Reverb Parameters
        let reverbSize = AUParameterTree.createParameter(
            withIdentifier: "reverbSize",
            name: "Room Size",
            address: ParameterAddress.reverbSize.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        reverbSize.value = 0.5
        
        let reverbDamping = AUParameterTree.createParameter(
            withIdentifier: "reverbDamping",
            name: "Damping",
            address: ParameterAddress.reverbDamping.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        reverbDamping.value = 0.5
        
        let reverbMix = AUParameterTree.createParameter(
            withIdentifier: "reverbMix",
            name: "Reverb Mix",
            address: ParameterAddress.reverbMix.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        reverbMix.value = 0.3
        
        // Delay Parameters
        let delayTime = AUParameterTree.createParameter(
            withIdentifier: "delayTime",
            name: "Delay Time",
            address: ParameterAddress.delayTime.rawValue,
            min: 1.0, max: 2000.0,
            unit: .milliseconds,
            unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayTime.value = 250.0
        
        let delayFeedback = AUParameterTree.createParameter(
            withIdentifier: "delayFeedback",
            name: "Feedback",
            address: ParameterAddress.delayFeedback.rawValue,
            min: 0.0, max: 0.95,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayFeedback.value = 0.4
        
        let delayMix = AUParameterTree.createParameter(
            withIdentifier: "delayMix",
            name: "Delay Mix",
            address: ParameterAddress.delayMix.rawValue,
            min: 0.0, max: 1.0,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        delayMix.value = 0.3
        
        // Gain Parameters
        let inputGain = AUParameterTree.createParameter(
            withIdentifier: "inputGain",
            name: "Input Gain",
            address: ParameterAddress.inputGain.rawValue,
            min: -24.0, max: 24.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        inputGain.value = 0.0
        
        let outputGain = AUParameterTree.createParameter(
            withIdentifier: "outputGain",
            name: "Output Gain",
            address: ParameterAddress.outputGain.rawValue,
            min: -24.0, max: 24.0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        outputGain.value = 0.0
        
        // Create groups
        let eqGroup = AUParameterTree.createGroup(withIdentifier: "eq", name: "Equalizer", children: [eqLowGain, eqMidGain, eqHighGain])
        let compGroup = AUParameterTree.createGroup(withIdentifier: "comp", name: "Compressor", children: [compThreshold, compRatio, compAttack, compRelease])
        let reverbGroup = AUParameterTree.createGroup(withIdentifier: "reverb", name: "Reverb", children: [reverbSize, reverbDamping, reverbMix])
        let delayGroup = AUParameterTree.createGroup(withIdentifier: "delay", name: "Delay", children: [delayTime, delayFeedback, delayMix])
        let gainGroup = AUParameterTree.createGroup(withIdentifier: "gain", name: "Gain", children: [inputGain, outputGain])
        
        _parameterTree = AUParameterTree.createTree(withChildren: [eqGroup, compGroup, reverbGroup, delayGroup, gainGroup])
        
        // Parameter value observer
        _parameterTree?.implementorValueObserver = { [weak self] param, value in
            self?.setParameter(address: param.address, value: value)
        }
        
        _parameterTree?.implementorValueProvider = { [weak self] param in
            return self?.getParameter(address: param.address) ?? 0.0
        }
    }
    
    private func setParameter(address: AUParameterAddress, value: AUValue) {
        switch address {
        case ParameterAddress.eqLowGain.rawValue:
            if engine.eq.bands.count > 0 { engine.eq.bands[0].gain = value }
        case ParameterAddress.eqMidGain.rawValue:
            if engine.eq.bands.count > 2 { engine.eq.bands[2].gain = value }
        case ParameterAddress.eqHighGain.rawValue:
            if engine.eq.bands.count > 4 { engine.eq.bands[4].gain = value }
        case ParameterAddress.compThreshold.rawValue:
            engine.compressor.threshold = value
        case ParameterAddress.compRatio.rawValue:
            engine.compressor.ratio = value
        case ParameterAddress.compAttack.rawValue:
            engine.compressor.attack = value
        case ParameterAddress.compRelease.rawValue:
            engine.compressor.release = value
        case ParameterAddress.reverbSize.rawValue:
            engine.reverb.roomSize = value
        case ParameterAddress.reverbDamping.rawValue:
            engine.reverb.damping = value
        case ParameterAddress.reverbMix.rawValue:
            engine.reverb.wetLevel = value
            engine.reverb.dryLevel = 1.0 - value
        case ParameterAddress.delayTime.rawValue:
            engine.delay.delayTimeL = value
            engine.delay.delayTimeR = value
        case ParameterAddress.delayFeedback.rawValue:
            engine.delay.feedback = value
        case ParameterAddress.delayMix.rawValue:
            engine.delay.wetLevel = value
            engine.delay.dryLevel = 1.0 - value
        case ParameterAddress.inputGain.rawValue:
            engine.inputGain = value
        case ParameterAddress.outputGain.rawValue:
            engine.outputGain = value
        default:
            break
        }
    }
    
    private func getParameter(address: AUParameterAddress) -> AUValue {
        switch address {
        case ParameterAddress.eqLowGain.rawValue:
            return engine.eq.bands.count > 0 ? engine.eq.bands[0].gain : 0
        case ParameterAddress.eqMidGain.rawValue:
            return engine.eq.bands.count > 2 ? engine.eq.bands[2].gain : 0
        case ParameterAddress.eqHighGain.rawValue:
            return engine.eq.bands.count > 4 ? engine.eq.bands[4].gain : 0
        case ParameterAddress.compThreshold.rawValue:
            return engine.compressor.threshold
        case ParameterAddress.compRatio.rawValue:
            return engine.compressor.ratio
        case ParameterAddress.compAttack.rawValue:
            return engine.compressor.attack
        case ParameterAddress.compRelease.rawValue:
            return engine.compressor.release
        case ParameterAddress.reverbSize.rawValue:
            return engine.reverb.roomSize
        case ParameterAddress.reverbDamping.rawValue:
            return engine.reverb.damping
        case ParameterAddress.reverbMix.rawValue:
            return engine.reverb.wetLevel
        case ParameterAddress.delayTime.rawValue:
            return engine.delay.delayTimeL
        case ParameterAddress.delayFeedback.rawValue:
            return engine.delay.feedback
        case ParameterAddress.delayMix.rawValue:
            return engine.delay.wetLevel
        case ParameterAddress.inputGain.rawValue:
            return engine.inputGain
        case ParameterAddress.outputGain.rawValue:
            return engine.outputGain
        default:
            return 0
        }
    }
    
    // MARK: - AUAudioUnit Overrides
    
    public override var parameterTree: AUParameterTree? {
        get { return _parameterTree }
        set { _parameterTree = newValue }
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusArray
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusArray
    }
    
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        engine.sampleRate = outputBus.format.sampleRate
        engine.reset()
    }
    
    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        engine.reset()
    }
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        let engine = self.engine
        
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock in
            
            guard let pullInputBlock = pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }
            
            var pullFlags: AudioUnitRenderActionFlags = []
            let status = pullInputBlock(&pullFlags, timestamp, frameCount, 0, outputData)
            
            if status != noErr {
                return status
            }
            
            // Process audio through DSP engine
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            
            for buffer in ablPointer {
                guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                
                let channelCount = Int(buffer.mNumberChannels)
                let sampleCount = Int(frameCount) * channelCount
                
                // Create audio buffer
                var audioBuffer = AudioBuffer(frameCount: Int(frameCount), channelCount: channelCount)
                
                // Copy input samples
                for i in 0..<sampleCount {
                    audioBuffer.samples[i] = samples[i]
                }
                
                // Process through engine
                engine.process(&audioBuffer)
                
                // Copy output samples
                for i in 0..<sampleCount {
                    samples[i] = audioBuffer.samples[i]
                }
            }
            
            return noErr
        }
    }
}
