// Knob.swift
// Professional rotary knob control for audio parameters

#if canImport(SwiftUI)
import SwiftUI

/// Rotary knob control with value display
public struct Knob: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var label: String
    var unit: String
    var defaultValue: Float
    var sensitivity: Float
    var displayFormat: String
    var accentColor: Color
    
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    
    public init(
        value: Binding<Float>,
        range: ClosedRange<Float> = 0...1,
        label: String = "",
        unit: String = "",
        defaultValue: Float = 0,
        sensitivity: Float = 0.005,
        displayFormat: String = "%.1f",
        accentColor: Color = PluginColors.accentPrimary
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.unit = unit
        self.defaultValue = defaultValue
        self.sensitivity = sensitivity
        self.displayFormat = displayFormat
        self.accentColor = accentColor
    }
    
    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var rotation: Angle {
        // Rotation from -135° to +135° (270° range)
        .degrees(Double(normalizedValue) * 270 - 135)
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Label
            Text(label)
                .font(PluginFonts.label)
                .foregroundColor(PluginColors.textSecondary)
            
            // Knob
            ZStack {
                // Outer ring (track)
                Circle()
                    .stroke(PluginColors.knobRing, lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                // Active arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + CGFloat(normalizedValue) * 0.75)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(90))
                
                // Knob body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                PluginColors.backgroundLight,
                                PluginColors.knobBackground
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                
                // Indicator line
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 12)
                    .offset(y: -12)
                    .rotationEffect(rotation)
                    .shadow(color: accentColor.opacity(0.6), radius: 3)
            }
            .frame(width: 60, height: 60)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragValue = gesture.location.y
                        }
                        
                        let delta = Float(lastDragValue - gesture.location.y) * sensitivity
                        lastDragValue = gesture.location.y
                        
                        let newValue = value + delta * (range.upperBound - range.lowerBound)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                // Double-tap to reset to default
                withAnimation(.easeInOut(duration: 0.2)) {
                    value = defaultValue
                }
            }
            
            // Value display
            Text("\(String(format: displayFormat, value))\(unit)")
                .font(PluginFonts.value)
                .foregroundColor(isDragging ? accentColor : PluginColors.textPrimary)
                .frame(minWidth: 50)
        }
        .frame(width: 70)
    }
}

/// Small variant of the knob
public struct SmallKnob: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var label: String
    var accentColor: Color
    
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    
    public init(
        value: Binding<Float>,
        range: ClosedRange<Float> = 0...1,
        label: String = "",
        accentColor: Color = PluginColors.accentPrimary
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.accentColor = accentColor
    }
    
    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var rotation: Angle {
        .degrees(Double(normalizedValue) * 270 - 135)
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(PluginColors.knobBackground)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .trim(from: 0.125, to: 0.125 + CGFloat(normalizedValue) * 0.75)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(90))
                
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 8)
                    .offset(y: -7)
                    .rotationEffect(rotation)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragValue = gesture.location.y
                        }
                        let delta = Float(lastDragValue - gesture.location.y) * 0.008
                        lastDragValue = gesture.location.y
                        let newValue = value + delta * (range.upperBound - range.lowerBound)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            
            Text(label)
                .font(PluginFonts.small)
                .foregroundColor(PluginColors.textDimmed)
        }
    }
}

private struct KnobPreviews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            Knob(
                value: .constant(0.5),
                range: 0...1,
                label: "GAIN",
                unit: " dB",
                defaultValue: 0,
                displayFormat: "%.1f"
            )
        
            Knob(
                value: .constant(-12.0),
                range: -30...10,
                label: "THRESHOLD",
                unit: " dB",
                defaultValue: -20,
                displayFormat: "%.1f",
                accentColor: PluginColors.accentSecondary
            )
        }
        .padding()
        .background(PluginColors.backgroundDark)
    }
}
#endif
