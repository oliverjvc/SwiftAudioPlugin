// ReverbView.swift
// Reverb panel with room visualization

#if canImport(SwiftUI)
import SwiftUI
import DSP

/// Room size visualization
struct RoomVisualization: View {
    var roomSize: Float
    var damping: Float
    var width: Float
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 10
            
            // Draw room rings based on room size
            let ringCount = 5
            for i in 0..<ringCount {
                let progress = Float(i + 1) / Float(ringCount)
                let radius = maxRadius * CGFloat(roomSize * progress)
                let opacity = Double(1 - progress) * (1 - Double(damping) * 0.7)
                
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(PluginColors.accentPurple.opacity(opacity)),
                    lineWidth: 2
                )
            }
            
            // Draw stereo width indicator
            let widthAngle = Double(width) * .pi / 4
            var leftPath = Path()
            leftPath.move(to: center)
            leftPath.addLine(to: CGPoint(
                x: center.x - maxRadius * CGFloat(sin(widthAngle)),
                y: center.y - maxRadius * CGFloat(cos(widthAngle))
            ))
            
            var rightPath = Path()
            rightPath.move(to: center)
            rightPath.addLine(to: CGPoint(
                x: center.x + maxRadius * CGFloat(sin(widthAngle)),
                y: center.y - maxRadius * CGFloat(cos(widthAngle))
            ))
            
            context.stroke(leftPath, with: .color(PluginColors.accentPurple.opacity(0.5)), lineWidth: 1)
            context.stroke(rightPath, with: .color(PluginColors.accentPurple.opacity(0.5)), lineWidth: 1)
            
            // Center point
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                with: .color(PluginColors.accentPurple)
            )
        }
        .background(PluginColors.backgroundDark)
        .cornerRadius(8)
    }
}

/// Complete reverb panel
public struct ReverbPanel: View {
    @ObservedObject var reverb: Reverb
    
    public init(reverb: Reverb) {
        self.reverb = reverb
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                ToggleButton(isOn: $reverb.isEnabled, label: "REVERB", onColor: PluginColors.accentPurple)
                Spacer()
                Text("ALGORITHMIC REVERB")
                    .font(PluginFonts.sectionTitle)
                    .foregroundColor(PluginColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                // Room visualization
                RoomVisualization(
                    roomSize: reverb.roomSize,
                    damping: reverb.damping,
                    width: reverb.width
                )
                .frame(width: 120, height: 120)
                
                // Knobs
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Knob(
                            value: $reverb.roomSize,
                            range: 0...1,
                            label: "ROOM SIZE",
                            unit: "",
                            defaultValue: 0.5,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentPurple
                        )
                        
                        Knob(
                            value: $reverb.damping,
                            range: 0...1,
                            label: "DAMPING",
                            unit: "",
                            defaultValue: 0.5,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentPurple
                        )
                        
                        Knob(
                            value: $reverb.width,
                            range: 0...1,
                            label: "WIDTH",
                            unit: "",
                            defaultValue: 1,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentPurple
                        )
                    }
                    
                    HStack(spacing: 16) {
                        Knob(
                            value: $reverb.preDelay,
                            range: 0...200,
                            label: "PRE-DELAY",
                            unit: " ms",
                            defaultValue: 20,
                            displayFormat: "%.0f",
                            accentColor: PluginColors.accentPurple
                        )
                        
                        Knob(
                            value: $reverb.dryLevel,
                            range: 0...1,
                            label: "DRY",
                            unit: "",
                            defaultValue: 0.7,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentPurple
                        )
                        
                        Knob(
                            value: $reverb.wetLevel,
                            range: 0...1,
                            label: "WET",
                            unit: "",
                            defaultValue: 0.3,
                            displayFormat: "%.2f",
                            accentColor: PluginColors.accentPurple
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

#Preview {
    ReverbPanel(reverb: Reverb())
        .frame(width: 550)
        .background(PluginColors.backgroundMedium)
}
#endif
