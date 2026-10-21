#if os(macOS)
import AudioToolbox
import DSP
import SwiftUI

/// The graph operates on control-thread copies, never the render-owned DSP engine.
struct EqualizerEditor: View {
    @ObservedObject var model: ParameterModel
    @Binding var selectedBand: Int
    @State private var dragging = false

    private var sampleRate: Double { model.unit.outputBusses[0].format.sampleRate }
    private var maximumFrequency: Float { min(20000, Float(sampleRate * 0.45)) }
    private func address(_ band: Int, _ offset: Int = 0) -> AUParameterAddress {
        AUParameterAddress(50 + band * 4 + offset)
    }
    private func value(_ band: Int, _ offset: Int, fallback: Float) -> Float {
        model.values[address(band, offset)] ?? fallback
    }
    private var enabled: Bool { (model.values[45] ?? 1) >= 0.5 }
    private var bands: [EQBand] {
        (0..<5).map { index in
            let band = EQBand(frequency: min(maximumFrequency, value(index, 0, fallback: 1000)),
                              gain: value(index, 1, fallback: 0), q: value(index, 2, fallback: 1))
            band.setSampleRate(sampleRate)
            band.isEnabled = value(index, 3, fallback: 1) >= 0.5
            return band
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shape your sound").font(.system(size: 23, weight: .medium))
                    Text("Five bands. One clear picture.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: Binding(get: { enabled }, set: { model.set(45, $0 ? 1 : 0) }))
                    .toggleStyle(.switch).controlSize(.mini).fixedSize()
                Button("Reset") { model.resetGroup("Equalizer") }.font(.system(size: 10))
            }
            graph.frame(height: 220)
                .background(EditorPalette.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04)))
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { band in
                    Button { selectedBand = band } label: {
                        HStack(spacing: 6) {
                            Circle().fill(EditorPalette.bands[band])
                                .frame(width: 5, height: 5)
                                .opacity(value(band, 3, fallback: 1) >= 0.5 ? 1 : 0.25)
                            Text("B\(band + 1)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        }.frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(selectedBand == band ? EditorPalette.bands[band].opacity(0.12) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedBand == band ? EditorPalette.bands[band].opacity(0.4) : Color.white.opacity(0.06)))
                    }.buttonStyle(.plain).accessibilityLabel("Select EQ band \(band + 1)")
                }
            }
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { offset in
                    if let spec = ParameterSpec.all.first(where: { $0.address == address(selectedBand, offset) }) {
                        EditorKnob(spec: spec, value: model.binding(spec), color: EditorPalette.bands[selectedBand]) {
                            if $0 { model.beginGesture() } else { model.endGesture() }
                        }
                    }
                }
                VStack(spacing: 10) {
                    Text("BAND \(selectedBand + 1)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EditorPalette.bands[selectedBand])
                    Toggle("Enabled", isOn: Binding(
                        get: { value(selectedBand, 3, fallback: 1) >= 0.5 },
                        set: { model.set(address(selectedBand, 3), $0 ? 1 : 0) }
                    )).toggleStyle(.switch).controlSize(.mini).fixedSize()
                    Text("PEAK FILTER").font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity)
            }.padding(18).background(EditorPalette.panel, in: RoundedRectangle(cornerRadius: 12))
        }
        .onDisappear { if dragging { dragging = false; model.endGesture() } }
    }

    private var graph: some View {
        let filters = bands
        return GeometryReader { geometry in
            let rect = CGRect(x: 36, y: 16, width: max(1, geometry.size.width - 52),
                              height: max(1, geometry.size.height - 48))
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for db: Float in [-24, -12, 0, 12, 24] {
                        let y = yPosition(db, in: rect)
                        var line = Path()
                        line.move(to: CGPoint(x: rect.minX, y: y))
                        line.addLine(to: CGPoint(x: rect.maxX, y: y))
                        context.stroke(line, with: .color(.white.opacity(db == 0 ? 0.15 : 0.04)), lineWidth: 1)
                        context.draw(Text(db > 0 ? "+\(Int(db))" : "\(Int(db))")
                            .font(.system(size: 8, design: .monospaced)).foregroundColor(.secondary),
                            at: CGPoint(x: 18, y: y))
                    }
                    for frequency: Float in [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
                        where frequency <= maximumFrequency {
                        let x = xPosition(frequency, in: rect)
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: rect.minY))
                        line.addLine(to: CGPoint(x: x, y: rect.maxY))
                        context.stroke(line, with: .color(.white.opacity(0.035)), lineWidth: 1)
                        let label = frequency >= 1000 ? "\(Int(frequency / 1000))k" : "\(Int(frequency))"
                        context.draw(Text(label).font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.secondary), at: CGPoint(x: x, y: rect.maxY + 15))
                    }
                    for (index, filter) in filters.enumerated() where filter.isEnabled && enabled {
                        let path = responsePath(in: rect) { filter.magnitudeResponse(at: $0) }
                        context.stroke(path, with: .color(EditorPalette.bands[index].opacity(index == selectedBand ? 0.65 : 0.2)),
                                       lineWidth: 1)
                    }
                    let total = responsePath(in: rect) { frequency in
                        enabled ? filters.reduce(Float(1)) { $0 * $1.magnitudeResponse(at: frequency) } : 1
                    }
                    var fill = total
                    fill.addLine(to: CGPoint(x: rect.maxX, y: yPosition(0, in: rect)))
                    fill.addLine(to: CGPoint(x: rect.minX, y: yPosition(0, in: rect)))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(EditorPalette.accent.opacity(0.07)))
                    context.stroke(total, with: .color(enabled ? EditorPalette.accent : Color.gray),
                                   style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
                ForEach(0..<5, id: \.self) { band in
                    Text("\(band + 1)").font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(selectedBand == band ? EditorPalette.background : EditorPalette.bands[band])
                        .frame(width: 23, height: 23)
                        .background(selectedBand == band ? EditorPalette.bands[band] : EditorPalette.panel, in: Circle())
                        .overlay(Circle().stroke(EditorPalette.bands[band], lineWidth: 1.5))
                        .opacity(value(band, 3, fallback: 1) >= 0.5 ? 1 : 0.4)
                        .position(x: xPosition(min(maximumFrequency, value(band, 0, fallback: 1000)), in: rect),
                                  y: yPosition(value(band, 1, fallback: 0), in: rect))
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("eqGraph"))
                            .onChanged { event in
                                if !dragging { dragging = true; model.beginGesture() }
                                selectedBand = band
                                let x = min(rect.maxX, max(rect.minX, event.location.x))
                                let y = min(rect.maxY, max(rect.minY, event.location.y))
                                model.set(address(band), frequency(at: (x - rect.minX) / rect.width))
                                model.set(address(band, 1), Float((rect.midY - y) / rect.height) * 48)
                            }.onEnded { _ in dragging = false; model.endGesture() })
                        .onTapGesture(count: 2) { selectedBand = band; model.set(address(band, 1), 0) }
                        .onTapGesture { selectedBand = band }
                        .help("Band \(band + 1): drag horizontally for frequency and vertically for gain. Double-click resets gain.")
                        .accessibilityLabel("EQ band \(band + 1)")
                        .accessibilityValue(String(format: "%.0f Hz, %.1f dB", value(band, 0, fallback: 1000),
                                                  value(band, 1, fallback: 0)))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { selectedBand = band }
                }
            }.coordinateSpace(name: "eqGraph")
        }
    }
    private func xPosition(_ frequency: Float, in rect: CGRect) -> CGFloat {
        let bounded = min(maximumFrequency, max(20, frequency))
        return rect.minX + rect.width * CGFloat(log(bounded / 20) / log(maximumFrequency / 20))
    }
    private func yPosition(_ db: Float, in rect: CGRect) -> CGFloat {
        rect.midY - rect.height * CGFloat(min(24, max(-24, db)) / 48)
    }
    private func frequency(at position: CGFloat) -> Float {
        20 * pow(maximumFrequency / 20, Float(position))
    }
    private func responsePath(in rect: CGRect, magnitude: (Float) -> Float) -> Path {
        Path { path in
            for point in 0...240 {
                let position = CGFloat(point) / 240
                let linear = magnitude(frequency(at: position))
                let db = 20 * log10(max(0.000001, linear))
                let location = CGPoint(x: rect.minX + rect.width * position, y: yPosition(db, in: rect))
                if point == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
        }
    }
}
#endif
