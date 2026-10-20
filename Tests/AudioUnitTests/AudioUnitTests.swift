#if os(macOS)
import Testing
import AudioToolbox
import AVFoundation
@testable import AudioUnitPlugin

struct AudioUnitTests {
    @Test func parametersAndStateRoundTrip() throws {
        let unit = try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
        #expect(unit.parameterTree?.allParameters.count == 50)
        unit.parameterTree?.parameter(withAddress: 51)?.value = 8
        unit.parameterTree?.parameter(withAddress: 30)?.value = 650
        let restored = try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
        restored.fullState = unit.fullState
        #expect(restored.parameterTree?.parameter(withAddress: 51)?.value == 8)
        #expect(restored.parameterTree?.parameter(withAddress: 30)?.value == 650)
    }
}
#endif
