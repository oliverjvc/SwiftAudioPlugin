// CompressorView.swift
// Compressor panel with gain reduction visualization

#if canImport(SwiftUI)
import SwiftUI
import DSP

/// Compression transfer curve visualization
public struct CompressionCurve: View {
    @ObservedObject var compressor: Compressor
    var size: CGFloat
    
    public init(compressor: Compressor, size: CGFloat = 120) {
        self.compressor = compressor
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let range: Float = 60 // dB range
            
            // Draw grid
            for i in 1..<6 {
                let pos = CGFloat(i) * size / 6
                
                // Vertical line
                var vPath = Path()
                vPath.move(to: CGPoint(x: pos, y: 0))
                vPath.addLine(to: CGPoint(x: pos, y: size))
                context.stroke(vPath, with: .color(PluginColors.backgroundLight), lineWidth: 0.5)
                
                // Horizontal line
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: pos))
                hPath.addLine(to: CGPoint(x: size, y: pos))
                context.stroke(hPath, with: .color(PluginColors.backgroundLight), lineWidth: 0.5)
            }
            
            // Draw 1:1 line
            var unityPath = Path()
            unityPath.move(to: CGPoint(x: 0, y: size))
            unityPath.addLine(to: CGPoint(x: size, y: 0))
            context.stroke(unityPath, with: .color(PluginColors.textDimmed), lineWidth: 1)
            
            // Draw compression curve
            var curvePath = Path()
            curvePath.move(to: CGPoint(x: 0, y: size))
            
            for i in 0..<Int(size) {
                let inputDB = Float(i) / Float(size) * range - range
                var outputDB = inputDB
                
                let kneeStart = compressor.threshold - compressor.knee / 2
                let kneeEnd = compressor.threshold + compressor.knee / 2
                
                if inputDB > kneeEnd {
                    // Above knee
                    outputDB = compressor.threshold + (inputDB - compressor.threshold) / compressor.ratio
                } else if inputDB > kneeStart {
                    // In knee
                    let kneeRatio = (inputDB - kneeStart) / compressor.knee
                    let compression = (inputDB - compressor.threshold) * (1 - 1/compressor.ratio) * kneeRatio
                    outputDB = inputDB - compression
                }
                
                let x = CGFloat(i)
                let y = size - CGFloat((outputDB + range) / range) * size
                curvePath.addLine(to: CGPoint(x: x, y: max(0, min(size, y))))
            }
            
            context.stroke(curvePath, with: .color(PluginColors.accentSecondary), lineWidth: 2)
            
            // Draw threshold line
            let thresholdX = CGFloat((compressor.threshold + range) / range) * size
            var thresholdPath = Path()
            thresholdPath.move(to: CGPoint(x: thresholdX, y: 0))
            thresholdPath.addLine(to: CGPoint(x: thresholdX, y: size))
            context.stroke(
                thresholdPath,
                with: .color(PluginColors.accentSecondary.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
        }
        .frame(width: size, height: size)
        .background(PluginColors.backgroundDark)
        .cornerRadius(8)
    }
}

/// Complete compressor panel
public struct CompressorPanel: View {
    @ObservedObject var compressor: Compressor
    
    public init(compressor: Compressor) {
        self.compressor = compressor
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                ToggleButton(isOn: $compressor.isEnabled, label: "COMP", onColor: PluginColors.accentSecondary)
                Spacer()
                Text("DYNAMICS COMPRESSOR")
                    .font(PluginFonts.sectionTitle)
                    .foregroundColor(PluginColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                // Left side: Meters
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        StereoMeter(
                            leftLevel: compressor.inputLevel,
                            rightLevel: compressor.inputLevel,
                            label: "IN",
                            height: 100
                        )
                        
                        GainReductionMeter(
                            reduction: compressor.gainReduction,
                            height: 100
                        )
                        
                        StereoMeter(
                            leftLevel: compressor.outputLevel,
                            rightLevel: compressor.outputLevel,
                            label: "OUT",
                            height: 100
                        )
                    }
                }
                
                // Center: Transfer curve
                VStack(spacing: 4) {
                    CompressionCurve(compressor: compressor, size: 100)
                    Text("IN → OUT")
                        .font(PluginFonts.small)
                        .foregroundColor(PluginColors.textDimmed)
                }
                
                // Right side: Knobs
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Knob(
                            value: $compressor.threshold,
                            range: -60...0,
                            label: "THRESHOLD",
                            unit: " dB",
                            defaultValue: -20,
                            displayFormat: "%.1f",
                            accentColor: PluginColors.accentSecondary
                        )
                        
                        Knob(
                            value: $compressor.ratio,
                            range: 1...20,
                            label: "RATIO",
                            unit: ":1",
                            defaultValue: 4,
                            displayFormat: "%.1f",
                            accentColor: PluginColors.accentSecondary
                        )
                        
                        Knob(
                            value: $compressor.makeupGain,
                            range: 0...24,
                            label: "MAKEUP",
                            unit: " dB",
                            defaultValue: 0,
                            displayFormat: "%.1f",
                            accentColor: PluginColors.accentSecondary
                        )
                    }
                    
                    HStack(spacing: 16) {
                        Knob(
                            value: $compressor.attack,
                            range: 0.1...100,
                            label: "ATTACK",
                            unit: " ms",
                            defaultValue: 10,
                            displayFormat: "%.1f",
                            accentColor: PluginColors.accentSecondary
                        )
                        
                        Knob(
                            value: $compressor.release,
                            range: 10...1000,
                            label: "RELEASE",
                            unit: " ms",
                            defaultValue: 100,
                            displayFormat: "%.0f",
                            accentColor: PluginColors.accentSecondary
                        )
                        
                        Knob(
                            value: $compressor.knee,
                            range: 0...12,
                            label: "KNEE",
                            unit: " dB",
                            defaultValue: 6,
                            displayFormat: "%.1f",
                            accentColor: PluginColors.accentSecondary
                        )
                    }
                }
            }
            .padding()
        }
        .padding()
        .panelStyle()
    }
}

private struct CompressorPanelPreviews: PreviewProvider {
    static var previews: some View {
        CompressorPanel(compressor: Compressor())
            .frame(width: 600)
            .background(PluginColors.backgroundMedium)
    }
}
#endif
