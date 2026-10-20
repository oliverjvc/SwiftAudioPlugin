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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 760, height: 560)
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

private final class ParameterModel: ObservableObject {
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
            self.values[spec.address] = bounded
            self.unit.parameterTree?.parameter(withAddress: spec.address)?.setValue(bounded, originator: self.token)
        })
    }
}

private struct PluginControls: View {
    @ObservedObject var model: ParameterModel
    @State private var selected = "Equalizer"
    private let accent = Color(red: 0.32, green: 0.84, blue: 0.76)
    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SWIFT AUDIO").font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("CHANNEL STRIP  /  OLIVER J").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Bypass", isOn: Binding(get: { (model.values[2] ?? 0) >= 0.5 }, set: {
                    model.binding(ParameterSpec.all.first { $0.address == 2 }!).wrappedValue = $0 ? 1 : 0
                })).toggleStyle(.switch)
            }
            HStack(spacing: 30) {
                parameterRow(ParameterSpec.all[0])
                parameterRow(ParameterSpec.all[1])
            }
            Divider()
            Picker("Processor", selection: $selected) {
                ForEach(ParameterSpec.groups.dropFirst(), id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 30), GridItem(.flexible())], spacing: 18) {
                    ForEach(ParameterSpec.all.filter { $0.group == selected }, id: \.address) { spec in
                        parameterRow(spec)
                    }
                }.padding(.vertical, 8)
            }
            HStack {
                Text("5-BAND EQ  →  COMP  →  DELAY  →  REVERB  →  LIMITER")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("AUDIO UNIT").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 460)
        .background(Color(red: 0.07, green: 0.09, blue: 0.12))
        .tint(accent)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            model.refreshAutomation()
        }
    }
    @ViewBuilder private func parameterRow(_ spec: ParameterSpec) -> some View {
        if spec.unit == .boolean {
            Toggle(spec.name, isOn: Binding(get: { model.binding(spec).wrappedValue >= 0.5 }, set: {
                model.binding(spec).wrappedValue = $0 ? 1 : 0
            })).toggleStyle(.switch).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 5) {
                HStack {
                    Text(spec.name).font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(label(spec)).font(.system(size: 11, design: .monospaced)).foregroundStyle(accent)
                }
                if spec.unit == .hertz {
                    Slider(value: Binding(get: { log10(model.binding(spec).wrappedValue) }, set: {
                        model.binding(spec).wrappedValue = pow(10, $0)
                    }), in: log10(spec.range.lowerBound)...log10(spec.range.upperBound))
                        .accessibilityLabel(spec.name)
                } else {
                    Slider(value: model.binding(spec), in: spec.range).accessibilityLabel(spec.name)
                }
            }
        }
    }
    private func label(_ spec: ParameterSpec) -> String {
        let value = model.values[spec.address] ?? spec.initial
        let suffix: String
        switch spec.unit {
        case .decibels: suffix = " dB"
        case .hertz: suffix = " Hz"
        case .milliseconds: suffix = " ms"
        case .ratio: suffix = ":1"
        default: suffix = ""
        }
        return String(format: abs(value) >= 100 ? "%.0f%@" : "%.2f%@", value, suffix)
    }
}

/// Referenced by the extension executable to ensure the framework is loaded.
@_cdecl("SwiftAudioPluginInitialize")
public func SwiftAudioPluginInitialize() {}
#endif
