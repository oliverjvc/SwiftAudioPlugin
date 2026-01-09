import AudioToolbox

@objc public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        return try SwiftAudioUnit(componentDescription: componentDescription, options: [])
    }
}
