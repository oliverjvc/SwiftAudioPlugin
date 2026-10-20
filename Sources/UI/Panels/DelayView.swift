// DelayView.swift
// Stereo delay panel with tempo sync

#if canImport(SwiftUI)
import SwiftUI
import DSP

/// Delay time visualization
struct DelayVisualization: View {
    var delayTimeL: Float
    var delayTimeR: Float
    var feedback: Float
    var pingPong: Bool
    
    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            let lineHeight: CGFloat = 30
            
            // Calculate normalized delays (max 1000ms for display)
            let maxDelay: Float = 1000
            let normL = CGFloat(min(delayTimeL, maxDelay) / maxDelay)
            let normR = CGFloat(min(delayTimeR, maxDelay) / maxDelay)
            
            // Draw feedback echoes
            let echoCount = 5
            for i in 0..<echoCount {
                let echoLevel = pow(feedback, Float(i + 1))
                let alpha = Double(echoLevel) * 0.8
                
                if pingPong {
                    // Alternating L/R
                    if i % 2 == 0 {
                        let x = normL * size.width * CGFloat(i + 1) / CGFloat(echoCount)
                        if x < size.width {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: centerY - lineHeight * CGFloat(echoLevel)))
                            path.addLine(to: CGPoint(x: x, y: centerY + lineHeight * CGFloat(echoLevel)))
                            context.stroke(path, with: .color(PluginColors.accentGreen.opacity(alpha)), lineWidth: 3)
                        }
                    } else {
                        let x = normR * size.width * CGFloat(i + 1) / CGFloat(echoCount)
                        if x < size.width {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: centerY - lineHeight * CGFloat(echoLevel)))
                            path.addLine(to: CGPoint(x: x, y: centerY + lineHeight * CGFloat(echoLevel)))
                            context.stroke(path, with: .color(PluginColors.accentPrimary.opacity(alpha)), lineWidth: 3)
                        }
                    }
                } else {
                    // Parallel L/R
                    let xL = normL * size.width * CGFloat(i + 1) / CGFloat(echoCount)
                    let xR = normR * size.width * CGFloat(i + 1) / CGFloat(echoCount)
                    
                    if xL < size.width {
                        var pathL = Path()
                        pathL.move(to: CGPoint(x: xL, y: centerY - 5 - lineHeight * CGFloat(echoLevel)))
                        pathL.addLine(to: CGPoint(x: xL, y: centerY - 5))
                        context.stroke(pathL, with: .color(PluginColors.accentGreen.opacity(alpha)), lineWidth: 3)
                    }
                    
                    if xR < size.width {
                        var pathR = Path()
                        pathR.move(to: CGPoint(x: xR, y: centerY + 5))
                        pathR.addLine(to: CGPoint(x: xR, y: centerY + 5 + lineHeight * CGFloat(echoLevel)))
                        context.stroke(pathR, with: .color(PluginColors.accentPrimary.opacity(alpha)), lineWidth: 3)
                    }
                }
            }
            
            // Draw input signal
            var inputPath = Path()
            inputPath.move(to: CGPoint(x: 0, y: centerY - lineHeight))
            inputPath.addLine(to: CGPoint(x: 0, y: centerY + lineHeight))
            context.stroke(inputPath, with: .color(PluginColors.textPrimary), lineWidth: 4)
            
            // Labels
            context.draw(
                Text("L").font(.system(size: 8)).foregroundColor(PluginColors.accentGreen),
                at: CGPoint(x: 10, y: centerY - lineHeight - 8)
            )
            context.draw(
                Text("R").font(.system(size: 8)).foregroundColor(PluginColors.accentPrimary),
                at: CGPoint(x: 10, y: centerY + lineHeight + 8)
            )
        }
        .background(PluginColors.backgroundDark)
        .cornerRadius(8)
    }
}

/// Tempo sync note selector
struct NoteDivisionSelector: View {
    @Binding var division: Float
    var label: String
    var accentColor: Color
    
    private let divisions: [(Float, String)] = [
        (0.0625, "1/16"),
        (0.125, "1/8"),
        (0.1875, "1/8D"),
        (0.25, "1/4"),
        (0.375, "1/4D"),
        (0.5, "1/2"),
        (1.0, "1/1")
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(PluginFonts.label)
                .foregroundColor(PluginColors.textSecondary)
            
            Menu {
                ForEach(divisions, id: \.0) { (value, name) in
                    Button(name) {
                        division = value
                    }
                }
            } label: {
                Text(divisions.first { $0.0 == division }?.1 ?? "1/4")
                    .font(PluginFonts.value)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(PluginColors.backgroundDark)
                    .cornerRadius(4)
            }
        }
    }
}

/// Complete delay panel
public struct DelayPanel: View {
    @ObservedObject var delay: StereoDelay
    
    public init(delay: StereoDelay) {
        self.delay = delay
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                ToggleButton(isOn: $delay.isEnabled, label: "DELAY", onColor: PluginColors.accentGreen)
                Spacer()
                
                // Tempo sync toggle
                ToggleButton(isOn: $delay.syncEnabled, label: "SYNC", onColor: PluginColors.accentPrimary)
                
                if delay.syncEnabled {
                    // Tempo input
                    HStack(spacing: 4) {
                        Text("BPM:")
                            .font(PluginFonts.label)
                            .foregroundColor(PluginColors.textSecondary)
                        
                        Text(String(format: "%.0f", delay.tempo))
                            .font(PluginFonts.value)
                            .foregroundColor(PluginColors.accentPrimary)
                    }
                }
                
                Spacer()
                
                // Ping-pong toggle
                ToggleButton(isOn: $delay.pingPong, label: "PING-PONG", onColor: PluginColors.accentSecondary)
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                // Delay visualization
                DelayVisualization(
                    delayTimeL: delay.delayTimeL,
                    delayTimeR: delay.delayTimeR,
                    feedback: delay.feedback,
                    pingPong: delay.pingPong
                )
                .frame(width: 150, height: 80)
                
                // Time controls
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        if delay.syncEnabled {
                            NoteDivisionSelector(
                                division: $delay.syncDivisionL,
                                label: "LEFT",
                                accentColor: PluginColors.accentGreen
                            )
                            NoteDivisionSelector(
                                division: $delay.syncDivisionR,
                                label: "RIGHT",
                                accentColor: PluginColors.accentPrimary
                            )
                        } else {
                            Knob(
                                value: $delay.delayTimeL,
                                range: 1...1000,
                                label: "TIME L",
                                unit: " ms",
                                defaultValue: 250,
                                displayFormat: "%.0f",
                                accentColor: PluginColors.accentGreen
                            )
                            
                            Knob(
                                value: $delay.delayTimeR,
                                range: 1...1000,
                                label: "TIME R",
                                unit: " ms",
                                defaultValue: 250,
                                displayFormat: "%.0f",
                                accentColor: PluginColors.accentPrimary
                            )
                        }
                        
                        Knob(
                            value: $delay.feedback,
                            range: 0...0.95,
                            label: "FEEDBACK",
                            unit: "",
                            defaultValue: 0.4,
                            displayFormat: "%.0f%%",
                            accentColor: PluginColors.accentGreen
                        )
                    }
                    
                    HStack(spacing: 16) {
                        Knob(
                            value: $delay.highCut,
                            range: 1000...20000,
                            label: "HI CUT",
                            unit: "",
                            defaultValue: 8000,
                            displayFormat: "%.0f",
                            accentColor: PluginColors.accentGreen
                        )
                        
                        Knob(
                            value: $delay.lowCut,
                            range: 20...500,
                            label: "LO CUT",
                            unit: "",
                            defaultValue: 100,
                            displayFormat: "%.0f",
                            accentColor: PluginColors.accentGreen
                        )
                        
                        Knob(
                            value: $delay.dryLevel,
                            range: 0...1,
                            label: "DRY",
                            unit: "",
                            defaultValue: 1,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentGreen
                        )
                        
                        Knob(
                            value: $delay.wetLevel,
                            range: 0...1,
                            label: "WET",
                            unit: "",
                            defaultValue: 0.3,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentGreen
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

private struct DelayPanelPreviews: PreviewProvider {
    static var previews: some View {
        DelayPanel(delay: StereoDelay())
            .frame(width: 600)
            .background(PluginColors.backgroundMedium)
    }
}
#endif
