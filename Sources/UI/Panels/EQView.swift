// EQView.swift
// Parametric EQ visualization and controls

#if canImport(SwiftUI)
import SwiftUI
import DSP

/// EQ frequency response curve visualization
public struct EQCurveView: View {
    @ObservedObject var eq: ParametricEQ
    var width: CGFloat
    var height: CGFloat
    
    public init(eq: ParametricEQ, width: CGFloat = 400, height: CGFloat = 150) {
        self.eq = eq
        self.width = width
        self.height = height
    }
    
    // Frequency range: 20Hz to 20kHz (log scale)
    private let minFreq: Float = 20
    private let maxFreq: Float = 20000
    private let minDB: Float = -18
    private let maxDB: Float = 18
    
    private func freqToX(_ freq: Float) -> CGFloat {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = log10(freq)
        return CGFloat((logFreq - logMin) / (logMax - logMin)) * width
    }
    
    private func xToFreq(_ x: CGFloat) -> Float {
        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logFreq = logMin + Float(x / width) * (logMax - logMin)
        return pow(10, logFreq)
    }
    
    private func dBToY(_ dB: Float) -> CGFloat {
        let normalized = (dB - minDB) / (maxDB - minDB)
        return height * CGFloat(1 - normalized)
    }
    
    public var body: some View {
        ZStack {
            // Background grid
            Canvas { context, size in
                // Horizontal grid lines (dB)
                let dbLines: [Float] = [-12, -6, 0, 6, 12]
                for db in dbLines {
                    let y = dBToY(db)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                    context.stroke(
                        path,
                        with: .color(db == 0 ? PluginColors.textDimmed : PluginColors.backgroundLight),
                        lineWidth: db == 0 ? 1 : 0.5
                    )
                }
                
                // Vertical grid lines (frequency)
                let freqLines: [Float] = [50, 100, 200, 500, 1000, 2000, 5000, 10000]
                for freq in freqLines {
                    let x = freqToX(freq)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    context.stroke(path, with: .color(PluginColors.backgroundLight), lineWidth: 0.5)
                }
            }
            
            // EQ curve
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: dBToY(0)))
                
                // Calculate combined response
                for i in 0..<Int(width) {
                    let freq = xToFreq(CGFloat(i))
                    var totalDB: Float = 0
                    
                    for band in eq.bands {
                        if band.isEnabled {
                            totalDB += calculateBandResponse(band: band, frequency: freq)
                        }
                    }
                    
                    let y = dBToY(totalDB)
                    path.addLine(to: CGPoint(x: CGFloat(i), y: y))
                }
                
                // Fill under curve
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: width, y: height))
                fillPath.addLine(to: CGPoint(x: 0, y: height))
                fillPath.closeSubpath()
                
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            PluginColors.accentPrimary.opacity(0.3),
                            PluginColors.accentPrimary.opacity(0.05)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: height)
                    )
                )
                
                context.stroke(path, with: .color(PluginColors.accentPrimary), lineWidth: 2)
            }
            
            // Band control points
            ForEach(0..<eq.bands.count, id: \.self) { index in
                let band = eq.bands[index]
                BandControlPoint(
                    band: band,
                    index: index,
                    freqToX: freqToX,
                    dBToY: dBToY,
                    xToFreq: xToFreq,
                    height: height
                )
            }
            
            // Frequency labels
            VStack {
                Spacer()
                HStack {
                    Text("20")
                    Spacer()
                    Text("100")
                    Spacer()
                    Text("1k")
                    Spacer()
                    Text("10k")
                    Spacer()
                    Text("20k")
                }
                .font(PluginFonts.small)
                .foregroundColor(PluginColors.textDimmed)
                .padding(.horizontal, 4)
            }
        }
        .frame(width: width, height: height)
        .background(PluginColors.backgroundDark)
        .cornerRadius(8)
    }
    
    private func calculateBandResponse(band: EQBand, frequency: Float) -> Float {
        // Simplified response calculation for visualization
        let ratio = frequency / band.frequency
        let logRatio = log2(ratio)
        let bandwidth = 1.0 / band.q
        let response = band.gain * exp(-logRatio * logRatio / (bandwidth * bandwidth))
        return response
    }
}

/// Draggable control point for EQ band
struct BandControlPoint: View {
    @ObservedObject var band: EQBand
    var index: Int
    var freqToX: (Float) -> CGFloat
    var dBToY: (Float) -> CGFloat
    var xToFreq: (CGFloat) -> Float
    var height: CGFloat
    
    @State private var isDragging = false
    
    private let bandColors: [Color] = [
        PluginColors.accentRed,
        PluginColors.accentSecondary,
        PluginColors.accentPrimary,
        PluginColors.accentGreen,
        PluginColors.accentPurple
    ]
    
    var body: some View {
        let x = freqToX(band.frequency)
        let y = dBToY(band.gain)
        let color = bandColors[index % bandColors.count]
        
        Circle()
            .fill(band.isEnabled ? color : PluginColors.textDimmed)
            .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
            .shadow(color: band.isEnabled ? color.opacity(0.5) : .clear, radius: 4)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Update frequency (X)
                        let newFreq = xToFreq(gesture.location.x)
                        band.frequency = max(20, min(20000, newFreq))
                        // Update gain (Y)
                        let normalizedY = 1 - Float(gesture.location.y / height)
                        band.gain = (normalizedY * 36) - 18  // -18 to +18 dB
                        band.updateCoefficients()
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                band.isEnabled.toggle()
            }
            .animation(.easeOut(duration: 0.1), value: isDragging)
    }
}

/// Complete EQ panel with curve and controls
public struct EQPanel: View {
    @ObservedObject var eq: ParametricEQ
    
    public init(eq: ParametricEQ) {
        self.eq = eq
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                ToggleButton(isOn: $eq.isEnabled, label: "EQ", onColor: PluginColors.accentPrimary)
                Spacer()
                Text("5-BAND PARAMETRIC EQ")
                    .font(PluginFonts.sectionTitle)
                    .foregroundColor(PluginColors.textSecondary)
                Spacer()
                Knob(
                    value: $eq.outputGain,
                    range: -12...12,
                    label: "OUTPUT",
                    unit: " dB",
                    defaultValue: 0,
                    displayFormat: "%+.1f"
                )
            }
            .padding(.horizontal)
            
            // EQ Curve
            EQCurveView(eq: eq, width: 500, height: 150)
                .padding(.horizontal)
            
            // Band controls
            HStack(spacing: 16) {
                ForEach(0..<eq.bands.count, id: \.self) { index in
                    EQBandControl(band: eq.bands[index], index: index)
                }
            }
            .padding()
        }
        .padding()
        .panelStyle()
    }
}

/// Individual EQ band control
struct EQBandControl: View {
    @ObservedObject var band: EQBand
    var index: Int
    
    private let bandColors: [Color] = [
        PluginColors.accentRed,
        PluginColors.accentSecondary,
        PluginColors.accentPrimary,
        PluginColors.accentGreen,
        PluginColors.accentPurple
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Band number with enable toggle
            Button(action: { band.isEnabled.toggle() }) {
                Text("\(index + 1)")
                    .font(PluginFonts.label)
                    .foregroundColor(band.isEnabled ? .white : PluginColors.textDimmed)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(band.isEnabled ? bandColors[index % bandColors.count] : PluginColors.backgroundDark)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Frequency knob
            Knob(
                value: $band.frequency,
                range: 20...20000,
                label: "FREQ",
                unit: "",
                defaultValue: 1000,
                sensitivity: 0.01,
                displayFormat: "%.0f",
                accentColor: bandColors[index % bandColors.count]
            )
            
            // Gain knob
            Knob(
                value: $band.gain,
                range: -18...18,
                label: "GAIN",
                unit: " dB",
                defaultValue: 0,
                displayFormat: "%+.1f",
                accentColor: bandColors[index % bandColors.count]
            )
            
            // Q knob
            SmallKnob(
                value: $band.q,
                range: 0.1...10,
                label: "Q",
                accentColor: bandColors[index % bandColors.count]
            )
        }
    }
}

#Preview {
    EQPanel(eq: ParametricEQ())
        .frame(width: 600)
        .background(PluginColors.backgroundMedium)
}
#endif
