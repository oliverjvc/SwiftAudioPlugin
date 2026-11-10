#if os(macOS)
import AudioToolbox
import CoreAudioKit
import SwiftUI

/// Kept in the embedded framework so Logic can load the AU in its own process.
@objc(SwiftAudioUnitViewController)
public final class SwiftAudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var unit: SwiftAudioUnit?
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let created = try SwiftAudioUnit(componentDescription: componentDescription)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.unit = created
            if self.isViewLoaded { self.showControls(for: created) }
        }
        return created
    }
    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 700))
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 640, height: 700)
        if let unit { showControls(for: unit) }
    }
    private func showControls(for unit: SwiftAudioUnit) {
        view.subviews.forEach { $0.removeFromSuperview() }
        let host = NSHostingView(rootView: PluginControls(model: ParameterModel(unit: unit)))
        host.appearance = NSAppearance(named: .darkAqua)
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

final class ParameterModel: ObservableObject {
    let unit: SwiftAudioUnit
    @Published var values: [AUParameterAddress: Float] = [:]
    private var token: AUParameterObserverToken?
    init(unit: SwiftAudioUnit) {
        self.unit = unit
        for parameter in unit.parameterTree!.allParameters { values[parameter.address] = parameter.value }
        token = unit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async { self?.values[address] = value }
        })
    }
    deinit { if let token { unit.parameterTree?.removeParameterObserver(token) } }
    func refreshAutomation() {
        // Scheduled render events update atomic values without calling UI observers on the audio thread.
        for parameter in unit.parameterTree!.allParameters {
            let current = parameter.value
            if values[parameter.address] != current { values[parameter.address] = current }
        }
    }
    func binding(_ spec: ParameterSpec) -> Binding<Float> {
        Binding(get: { self.values[spec.address] ?? spec.initial }, set: { value in
            let bounded = spec.bounded(value)
            self.unit.currentPreset = nil
            self.values[spec.address] = bounded
            self.unit.parameterTree?.parameter(withAddress: spec.address)?.setValue(bounded, originator: self.token)
        })
    }
}

/// Keep partially typed values (such as a lone minus sign) out of the DSP.
private struct ParameterValueField: View {
    let name: String
    @Binding var value: Float
    @State private var draft = ""
    @FocusState private var editing: Bool
    private func formatted() -> String { String(format: "%.2f", value) }
    private func commit() {
        if let parsed = Float(draft.replacingOccurrences(of: ",", with: ".")), parsed.isFinite {
            value = parsed
        }
        draft = formatted()
    }
    var body: some View {
        TextField(name, text: $draft)
            .textFieldStyle(.plain).multilineTextAlignment(.trailing)
            .font(.system(size: 11, design: .monospaced))
            .focused($editing)
            .accessibilityLabel("\(name) value")
            .onAppear { draft = formatted() }
            .onSubmit { commit(); editing = false }
            .onChange(of: editing) { focused in if !focused { commit() } }
            .onChange(of: value) { _ in if !editing { draft = formatted() } }
    }
}

private struct PluginControls: View {
    @ObservedObject var model: ParameterModel
    private let wood = Color(red: 0.82, green: 0.70, blue: 0.54)
    private var amount: Binding<Float> {
        let parameter = model.binding(ParameterSpec.all.first { $0.address == 3 }!)
        return Binding(get: { parameter.wrappedValue / 100 },
                       set: { parameter.wrappedValue = $0 * 100 })
    }
    private var bypassed: Bool { (model.values[2] ?? 0) >= 0.5 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Logic Pro")
                    .font(.system(size: 12, weight: .regular)).tracking(0.2)
                    .foregroundStyle(Color(red: 0.30, green: 0.21, blue: 0.14).opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.brown.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(.top, 30).padding(.horizontal, 32)

            Text("Classical Room Reverb")
                .font(.system(size: 44, weight: .regular, design: .serif))
                .foregroundStyle(Color(red: 0.33, green: 0.19, blue: 0.11))
                .minimumScaleFactor(0.75).lineLimit(1).padding(.top, 18)

            Spacer(minLength: 30)
            HStack(spacing: 40) {
                AmountDial(value: amount)
                Circle()
                    .fill(bypassed ? Color(red: 0.48, green: 0.40, blue: 0.32) : Color(red: 0.25, green: 0.82, blue: 0.22))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().fill(.white.opacity(bypassed ? 0.15 : 0.6)).frame(width: 10, height: 10).offset(x: -4, y: -4))
                    .shadow(color: bypassed ? .clear : .green.opacity(0.65), radius: 12)
                    .accessibilityHidden(true)
            }
            Text("Amount")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(red: 0.25, green: 0.16, blue: 0.10)).padding(.top, 26)
            Text("\(Int((amount.wrappedValue * 100).rounded()))%")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.42, green: 0.30, blue: 0.21).opacity(0.8)).padding(.top, 4)

            Spacer(minLength: 30)
            Button(bypassed ? "BYPASS · OFF" : "BYPASS") {
                model.binding(ParameterSpec.all.first { $0.address == 2 }!).wrappedValue = bypassed ? 0 : 1
            }
            .font(.system(size: 14, weight: .regular)).tracking(1.2)
            .foregroundStyle(Color(red: 0.36, green: 0.27, blue: 0.19))
            .buttonStyle(.plain)
            .padding(.horizontal, 30).padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brown.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brown.opacity(0.45), lineWidth: 1.2))
            }
            .help("Temporarily bypass the room reverb")
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 28)
        .frame(minWidth: 560, idealWidth: 640, minHeight: 620, idealHeight: 700)
        .background {
            RoundedRectangle(cornerRadius: 27)
                .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.88, blue: 0.74), wood,
                                              Color(red: 0.88, green: 0.77, blue: 0.61)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { WoodGrain().clipShape(RoundedRectangle(cornerRadius: 27)) }
                .overlay(RoundedRectangle(cornerRadius: 27).stroke(.white.opacity(0.7), lineWidth: 1.4))
                .shadow(color: Color(red: 0.29, green: 0.19, blue: 0.11).opacity(0.28), radius: 25, y: 13)
        }
        .padding(16).background(Color(red: 0.95, green: 0.94, blue: 0.91))
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            model.refreshAutomation()
        }
    }
}

private struct AmountDial: View {
    @Binding var value: Float
    @State private var dragOrigin: Float?
    private let size: CGFloat = 214

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for index in 0...40 {
                    let progress = Double(index) / 40
                    let angle = (-225 + 270 * progress) * Double.pi / 180
                    let inner = CGFloat(index % 5 == 0 ? 103 : 106)
                    let outer: CGFloat = 112
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
                    path.addLine(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
                    let color = progress <= Double(value)
                        ? Color(red: 0.36, green: 0.22, blue: 0.12).opacity(0.8)
                        : Color(red: 0.45, green: 0.33, blue: 0.23).opacity(0.48)
                    context.stroke(path, with: .color(color), lineWidth: index % 5 == 0 ? 2.2 : 1.3)
                }
            }
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.18, blue: 0.16),
                                              Color(red: 0.09, green: 0.09, blue: 0.09),
                                              Color(red: 0.16, green: 0.14, blue: 0.12)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size - 34, height: size - 34)
                .overlay(Circle().stroke(Color(red: 0.77, green: 0.66, blue: 0.51).opacity(0.85), lineWidth: 2))
                .overlay {
                    Capsule().fill(LinearGradient(colors: [.white, Color(red: 0.75, green: 0.68, blue: 0.56)],
                                                  startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: 29).offset(y: -(size / 2 - 51))
                        .rotationEffect(.degrees(Double(-135 + 270 * value)))
                }
                .shadow(color: .black.opacity(0.47), radius: 12, y: 8)
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1).padding(7))
        }
        .frame(width: size, height: size).contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if dragOrigin == nil { dragOrigin = value }
                value = min(1, max(0, (dragOrigin ?? value) - Float(gesture.translation.height / 230)))
            }
            .onEnded { _ in dragOrigin = nil })
        .accessibilityElement().accessibilityLabel("Reverb Amount")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityHint("Drag vertically or use the accessibility controls to change reverb amount")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.01)
            case .decrement: value = max(0, value - 0.01)
            @unknown default: break
            }
        }
    }
}

private struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            for row in 0..<66 {
                let y = CGFloat(row) * 11 + 4
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                let segments = 12
                for segment in 0..<segments {
                    let x = size.width * CGFloat(segment + 1) / CGFloat(segments)
                    let seed = Double(row * 37 + segment * 19)
                    let wave = CGFloat(sin(seed * 0.41) * 4.2 + cos(seed * 0.13) * 2.8)
                    let nextWave = CGFloat(sin((seed + 19) * 0.41) * 4.2 + cos((seed + 19) * 0.13) * 2.8)
                    let previousX = size.width * CGFloat(segment) / CGFloat(segments)
                    path.addCurve(to: CGPoint(x: x, y: y + nextWave),
                                  control1: CGPoint(x: previousX + size.width / CGFloat(segments) * 0.35, y: y + wave),
                                  control2: CGPoint(x: x - size.width / CGFloat(segments) * 0.35, y: y + nextWave))
                }
                context.stroke(path,
                               with: .color(Color(red: 0.37, green: 0.24, blue: 0.13).opacity(row % 5 == 0 ? 0.075 : 0.035)),
                               lineWidth: row % 5 == 0 ? 1 : 0.55)
            }
            let glow = Gradient(colors: [.white.opacity(0.17), .clear, .black.opacity(0.06)])
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(glow, startPoint: .zero,
                                               endPoint: CGPoint(x: size.width, y: size.height)))
        }
        .allowsHitTesting(false)
    }
}

/// Referenced by the extension executable to ensure the framework is loaded.
@_cdecl("SwiftAudioPluginInitialize")
public func SwiftAudioPluginInitialize() {}
#endif
