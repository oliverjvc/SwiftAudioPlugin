import CoreAudioKit
import SwiftUI

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    
    var audioUnit: SwiftAudioUnit?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set preferred size
        preferredContentSize = NSSize(width: 600, height: 400)
        
        // Create SwiftUI view
        let hostingView = NSHostingView(rootView: AudioUnitControlView(audioUnit: audioUnit))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try SwiftAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}

// MARK: - SwiftUI Control View

struct AudioUnitControlView: View {
    var audioUnit: SwiftAudioUnit?
    
    @State private var eqLowGain: Float = 0
    @State private var eqMidGain: Float = 0
    @State private var eqHighGain: Float = 0
    
    @State private var compThreshold: Float = -20
    @State private var compRatio: Float = 4
    
    @State private var reverbSize: Float = 0.5
    @State private var reverbMix: Float = 0.3
    
    @State private var delayTime: Float = 250
    @State private var delayMix: Float = 0.3
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Swift Audio Plugin")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 30) {
                // EQ Section
                VStack {
                    Text("EQ")
                        .font(.headline)
                    
                    ParameterSlider(label: "Low", value: $eqLowGain, range: -12...12, unit: "dB")
                    ParameterSlider(label: "Mid", value: $eqMidGain, range: -12...12, unit: "dB")
                    ParameterSlider(label: "High", value: $eqHighGain, range: -12...12, unit: "dB")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Compressor Section
                VStack {
                    Text("Compressor")
                        .font(.headline)
                    
                    ParameterSlider(label: "Threshold", value: $compThreshold, range: -60...0, unit: "dB")
                    ParameterSlider(label: "Ratio", value: $compRatio, range: 1...20, unit: ":1")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Reverb Section
                VStack {
                    Text("Reverb")
                        .font(.headline)
                    
                    ParameterSlider(label: "Size", value: $reverbSize, range: 0...1, unit: "")
                    ParameterSlider(label: "Mix", value: $reverbMix, range: 0...1, unit: "")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Delay Section
                VStack {
                    Text("Delay")
                        .font(.headline)
                    
                    ParameterSlider(label: "Time", value: $delayTime, range: 1...2000, unit: "ms")
                    ParameterSlider(label: "Mix", value: $delayMix, range: 0...1, unit: "")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct ParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text(String(format: "%.1f%@", value, unit))
                    .frame(width: 60, alignment: .trailing)
                    .font(.caption)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Float($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
        }
    }
}
