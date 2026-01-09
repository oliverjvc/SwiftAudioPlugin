import AudioToolbox
import CoreAudioKit

@objc public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    
    var auAudioUnit: AUAudioUnit?
    
    public func beginRequest(with context: NSExtensionContext) {
        // Required for NSExtensionRequestHandling but not used for AU
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        auAudioUnit = try SwiftAudioUnit(componentDescription: componentDescription, options: [])
        return auAudioUnit!
    }
}
