#if os(macOS)
import Testing
import AudioToolbox
import AVFoundation
@testable import AudioUnitPlugin

struct AudioUnitTests {
    private func makeUnit(channels: AVAudioChannelCount = 2, rate: Double = 48000) throws -> SwiftAudioUnit {
        let unit = try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        unit.maximumFramesToRender = 512
        // Isolate gain/automation from the nonlinear and time-based processors.
        for address: AUParameterAddress in [15, 24, 35, 40, 45] {
            unit.parameterTree!.parameter(withAddress: address)!.value = 0
        }
        try unit.allocateRenderResources()
        return unit
    }

    private func render(_ unit: SwiftAudioUnit, frames: AUAudioFrameCount = 64,
                        events: UnsafePointer<AURenderEvent>? = nil,
                        sample: Float = 0.1, time: Double = 0, block: AUInternalRenderBlock? = nil) throws -> [[Float]] {
        let output = AVAudioPCMBuffer(pcmFormat: unit.outputBusses[0].format, frameCapacity: frames)!
        output.frameLength = frames
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        stamp.mFlags = .sampleTimeValid
        stamp.mSampleTime = time
        let status = (block ?? unit.internalRenderBlock)(&flags, &stamp, frames, 0, output.mutableAudioBufferList, events) {
            _, _, count, _, data in
            let buffers = UnsafeMutableAudioBufferListPointer(data)
            for channel in 0..<buffers.count {
                let pointer = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
                for frame in 0..<Int(count) { pointer[frame] = sample * Float(channel + 1) }
            }
            return noErr
        }
        try #require(status == noErr)
        return (0..<Int(output.format.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: output.floatChannelData![channel], count: Int(frames)))
        }
    }

    @Test func hostCanCacheRenderBlockBeforeAllocation() throws {
        let unit = try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
        let block = unit.internalRenderBlock
        unit.shouldBypassEffect = true
        try unit.allocateRenderResources()
        #expect(try render(unit, block: block)[0].allSatisfy { $0 == 0.1 })
        unit.deallocateRenderResources()
        try unit.allocateRenderResources()
        #expect(try render(unit, block: block)[0].allSatisfy { $0 == 0.1 })
    }

    @Test func factoryPresetChangesParameters() throws {
        let unit = try makeUnit()
        unit.currentPreset = unit.factoryPresets![3]
        #expect(unit.parameterTree!.parameter(withAddress: 20)!.value == 0.8)
        #expect(unit.parameterTree!.parameter(withAddress: 32)!.value == 0.5)
        unit.currentPreset = unit.factoryPresets![0]
        #expect(unit.parameterTree!.parameter(withAddress: 20)!.value == 0.5)
    }

    @Test func parametersAndStateRoundTrip() throws {
        let unit = try makeUnit()
        #expect(unit.parameterTree?.allParameters.count == 50)
        unit.parameterTree?.parameter(withAddress: 51)?.value = 8
        unit.parameterTree?.parameter(withAddress: 30)?.value = 650
        let restored = try makeUnit()
        // Exercise the property-list representation used in AU presets/projects.
        let data = try PropertyListSerialization.data(fromPropertyList: unit.fullState!, format: .binary, options: 0)
        restored.fullState = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        #expect(restored.parameterTree?.parameter(withAddress: 51)?.value == 8)
        #expect(restored.parameterTree?.parameter(withAddress: 30)?.value == 650)
    }

    @Test(arguments: [AVAudioChannelCount(1), 2])
    func gainBypassAndVariableBlockSizes(channels: AVAudioChannelCount) throws {
        let unit = try makeUnit(channels: channels)
        unit.parameterTree!.parameter(withAddress: 1)!.value = -6.0206
        for frames: AUAudioFrameCount in [1, 17, 512, 63] {
            let audio = try render(unit, frames: frames)
            for channel in 0..<Int(channels) {
                #expect(audio[channel].allSatisfy { abs($0 - 0.05 * Float(channel + 1)) < 0.00001 })
            }
        }
        unit.shouldBypassEffect = true
        let bypassed = try render(unit)
        #expect(bypassed[0].allSatisfy { $0 == 0.1 })
    }

    @Test func scheduledGainChangeIsSampleAccurate() throws {
        let unit = try makeUnit()
        var event = AURenderEvent()
        event.parameter = AUParameterEvent(next: nil, eventSampleTime: 1032, eventType: .parameter,
            reserved: (0, 0, 0), rampDurationSampleFrames: 0, parameterAddress: 1, value: -6.0206)
        let audio = try withUnsafePointer(to: &event) { try render(unit, events: $0, time: 1000) }
        #expect(audio[0][0..<32].allSatisfy { abs($0 - 0.1) < 0.00001 })
        #expect(audio[0][32..<64].allSatisfy { abs($0 - 0.05) < 0.00001 })
    }

    @Test func rampContinuesAcrossBlocks() throws {
        let unit = try makeUnit()
        var event = AURenderEvent()
        event.parameter = AUParameterEvent(next: nil, eventSampleTime: 0, eventType: .parameterRamp,
            reserved: (0, 0, 0), rampDurationSampleFrames: 128, parameterAddress: 1, value: -12)
        let first = try withUnsafePointer(to: &event) { try render(unit, events: $0) }[0]
        let second = try render(unit, time: 64)[0]
        let last = try render(unit, time: 128)[0]
        #expect(abs(first[0] - 0.1) < 0.00001)
        #expect(first[63] > second[0])
        #expect(second[0] > second[63])
        #expect(last.allSatisfy { abs($0 - 0.025118864) < 0.00001 })
    }

    @Test func invalidFormatAndOversizedRenderAreRejected() throws {
        let unit = try makeUnit()
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        let output = AVAudioPCMBuffer(pcmFormat: unit.outputBusses[0].format, frameCapacity: 1024)!
        let status = unit.internalRenderBlock(&flags, &stamp, 1024, 0, output.mutableAudioBufferList, nil, nil)
        #expect(status == kAudioUnitErr_TooManyFramesToProcess)
        unit.deallocateRenderResources()
        try unit.inputBusses[0].setFormat(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!)
        #expect(throws: (any Error).self) { try unit.allocateRenderResources() }
    }

    @Test func nullOutputBuffersAndReset() throws {
        let unit = try makeUnit()
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { list.unsafeMutablePointer.deallocate() }
        for channel in 0..<2 { list[channel] = AudioToolbox.AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil) }
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        #expect(unit.internalRenderBlock(&flags, &stamp, 64, 0, list.unsafeMutablePointer, nil, { _, _, count, _, input in
            for buffer in UnsafeMutableAudioBufferListPointer(input) {
                buffer.mData!.assumingMemoryBound(to: Float.self).update(repeating: 0.1, count: Int(count))
            }
            return noErr
        }) == noErr)
        #expect(list[0].mData != nil)
        unit.reset()
        #expect(try render(unit)[0].allSatisfy { abs($0 - 0.1) < 0.00001 })
    }

    @Test(arguments: [8000.0, 44100, 48000, 96000, 192000])
    func fullChainProducesFiniteAudioAndReallocates(rate: Double) throws {
        let unit = try makeUnit(rate: rate)
        for parameter in unit.parameterTree!.allParameters where parameter.unit == .boolean {
            if parameter.address != 2 { parameter.value = 1 }
        }
        for block in 0..<10 {
            let audio = try render(unit, frames: 512, time: Double(block * 512))
            #expect(audio.flatMap { $0 }.allSatisfy { $0.isFinite && abs($0) < 2 })
        }
        unit.deallocateRenderResources()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        try unit.inputBusses[0].setFormat(format)
        try unit.outputBusses[0].setFormat(format)
        try unit.allocateRenderResources()
        #expect(try render(unit).flatMap { $0 }.allSatisfy(\.isFinite))
    }
}
#endif
