// AudioUnitPlugin.swift
// Audio Unit v3 wrapper for macOS DAW compatibility

#if os(macOS)
import Foundation
import AudioToolbox
import AVFoundation
import DSP

/// Audio Unit plugin factory
public class SwiftAudioPluginFactory {
    
    /// Create the Audio Unit component description
    public static var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: FourCharCode("swft"),
            componentManufacturer: FourCharCode("Demo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
    
    /// Register the Audio Unit with the system
    public static func registerAudioUnit() {
        AUAudioUnit.registerSubclass(
            SwiftAudioUnit.self,
            as: componentDescription,
            name: "Swift Audio Plugin",
            version: 1
        )
    }
}

/// Extension to create FourCharCode from string
extension FourCharCode {
    init(_ string: String) {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        self = result
    }
}

/// Main Audio Unit class
public class SwiftAudioUnit: AUAudioUnit {
    
    // MARK: - Properties
    
    private var engine: PluginEngine
    private var inputBus: AUAudioUnitBus!
    private var outputBus: AUAudioUnitBus!
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!
    
    // Parameter tree for DAW automation
    private var _parameterTree: AUParameterTree!
    
    // Parameters
    private var inputGainParam: AUParameter!
    private var outputGainParam: AUParameter!
    private var bypassParam: AUParameter!
    
    // Compressor parameters
    private var thresholdParam: AUParameter!
    private var ratioParam: AUParameter!
    private var attackParam: AUParameter!
    private var releaseParam: AUParameter!
    private var makeupGainParam: AUParameter!
    
    // Reverb parameters
    private var roomSizeParam: AUParameter!
    private var dampingParam: AUParameter!
    private var wetLevelParam: AUParameter!
    
    // MARK: - Initialization
    
    public override init(componentDescription: AudioComponentDescription,
                        options: AudioComponentInstantiationOptions = []) throws {
        
        engine = PluginEngine(sampleRate: 44100)
        
        try super.init(componentDescription: componentDescription, options: options)
        
        // Setup audio format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Create buses
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        
        // Setup parameters
        setupParameters()
    }
    
    // MARK: - Parameter Setup
    
    private func setupParameters() {
        // Input/Output parameters
        inputGainParam = AUParameterTree.createParameter(
            withIdentifier: "inputGain",
            name: "Input Gain",
            address: 0,
            min: -24,
            max: 24,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        outputGainParam = AUParameterTree.createParameter(
            withIdentifier: "outputGain",
            name: "Output Gain",
            address: 1,
            min: -24,
            max: 24,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        bypassParam = AUParameterTree.createParameter(
            withIdentifier: "bypass",
            name: "Bypass",
            address: 2,
            min: 0,
            max: 1,
            unit: .boolean,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        // Compressor parameters
        thresholdParam = AUParameterTree.createParameter(
            withIdentifier: "threshold",
            name: "Threshold",
            address: 10,
            min: -60,
            max: 0,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        ratioParam = AUParameterTree.createParameter(
            withIdentifier: "ratio",
            name: "Ratio",
            address: 11,
            min: 1,
            max: 20,
            unit: .ratio,
            unitName: ":1",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        attackParam = AUParameterTree.createParameter(
            withIdentifier: "attack",
            name: "Attack",
            address: 12,
            min: 0.1,
            max: 100,
            unit: .milliseconds,
            unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        releaseParam = AUParameterTree.createParameter(
            withIdentifier: "release",
            name: "Release",
            address: 13,
            min: 10,
            max: 1000,
            unit: .milliseconds,
            unitName: "ms",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        makeupGainParam = AUParameterTree.createParameter(
            withIdentifier: "makeupGain",
            name: "Makeup Gain",
            address: 14,
            min: 0,
            max: 24,
            unit: .decibels,
            unitName: "dB",
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        // Reverb parameters
        roomSizeParam = AUParameterTree.createParameter(
            withIdentifier: "roomSize",
            name: "Room Size",
            address: 20,
            min: 0,
            max: 1,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        dampingParam = AUParameterTree.createParameter(
            withIdentifier: "damping",
            name: "Damping",
            address: 21,
            min: 0,
            max: 1,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        wetLevelParam = AUParameterTree.createParameter(
            withIdentifier: "wetLevel",
            name: "Wet Level",
            address: 22,
            min: 0,
            max: 1,
            unit: .generic,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
        
        // Create groups
        let mainGroup = AUParameterTree.createGroup(
            withIdentifier: "main",
            name: "Main",
            children: [inputGainParam, outputGainParam, bypassParam]
        )
        
        let compressorGroup = AUParameterTree.createGroup(
            withIdentifier: "compressor",
            name: "Compressor",
            children: [thresholdParam, ratioParam, attackParam, releaseParam, makeupGainParam]
        )
        
        let reverbGroup = AUParameterTree.createGroup(
            withIdentifier: "reverb",
            name: "Reverb",
            children: [roomSizeParam, dampingParam, wetLevelParam]
        )
        
        // Create parameter tree
        _parameterTree = AUParameterTree.createTree(withChildren: [mainGroup, compressorGroup, reverbGroup])
        
        // Set initial values
        inputGainParam.value = 0
        outputGainParam.value = 0
        bypassParam.value = 0
        thresholdParam.value = -20
        ratioParam.value = 4
        attackParam.value = 10
        releaseParam.value = 100
        makeupGainParam.value = 0
        roomSizeParam.value = 0.5
        dampingParam.value = 0.5
        wetLevelParam.value = 0.3
        
        // Setup parameter observer
        _parameterTree.implementorValueObserver = { [weak self] param, value in
            self?.handleParameterChange(param, value: value)
        }
        
        _parameterTree.implementorValueProvider = { [weak self] param in
            return self?.getParameterValue(param) ?? param.value
        }
    }
    
    private func handleParameterChange(_ param: AUParameter, value: AUValue) {
        switch param.address {
        case 0: engine.inputGain = value
        case 1: engine.outputGain = value
        case 2: engine.isBypassed = value > 0.5
        case 10: engine.compressor.threshold = value
        case 11: engine.compressor.ratio = value
        case 12: engine.compressor.attack = value
        case 13: engine.compressor.release = value
        case 14: engine.compressor.makeupGain = value
        case 20: engine.reverb.roomSize = value
        case 21: engine.reverb.damping = value
        case 22: engine.reverb.wetLevel = value
        default: break
        }
    }
    
    private func getParameterValue(_ param: AUParameter) -> AUValue {
        switch param.address {
        case 0: return engine.inputGain
        case 1: return engine.outputGain
        case 2: return engine.isBypassed ? 1 : 0
        case 10: return engine.compressor.threshold
        case 11: return engine.compressor.ratio
        case 12: return engine.compressor.attack
        case 13: return engine.compressor.release
        case 14: return engine.compressor.makeupGain
        case 20: return engine.reverb.roomSize
        case 21: return engine.reverb.damping
        case 22: return engine.reverb.wetLevel
        default: return 0
        }
    }
    
    // MARK: - AUAudioUnit Overrides
    
    public override var parameterTree: AUParameterTree? {
        return _parameterTree
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
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
        // Capture engine reference
        let engine = self.engine
        
        return { [engine] actionFlags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock in
            
            guard let pullInputBlock = pullInputBlock else {
                return kAudioUnitErr_NoConnection
            }
            
            // Pull input
            var inputFlags = AudioUnitRenderActionFlags()
            let status = pullInputBlock(&inputFlags, timestamp, frameCount, 0, outputData)
            
            if status != noErr {
                return status
            }
            
            // Process audio
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            
            guard ablPointer.count >= 2,
                  let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            
            // Create audio buffer for processing
            var audioBuffer = AudioBuffer(frameCount: Int(frameCount), channelCount: 2)
            
            // Copy input to buffer
            for i in 0..<Int(frameCount) {
                audioBuffer.samples[i * 2] = leftBuffer[i]
                audioBuffer.samples[i * 2 + 1] = rightBuffer[i]
            }
            
            // Process
            engine.process(&audioBuffer)
            
            // Copy back to output
            for i in 0..<Int(frameCount) {
                leftBuffer[i] = audioBuffer.samples[i * 2]
                rightBuffer[i] = audioBuffer.samples[i * 2 + 1]
            }
            
            return noErr
        }
    }
}
#endif
