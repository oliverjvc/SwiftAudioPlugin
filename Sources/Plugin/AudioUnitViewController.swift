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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 640))
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 760, height: 640)
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
    @Published var activeSlot = 0
    @Published var meters: MeterSnapshot
    private var comparisons: [[AUParameterAddress: Float]] = []
    private var token: AUParameterObserverToken?
    init(unit: SwiftAudioUnit) {
        self.unit = unit
        self.meters = unit.meterSnapshot
        for parameter in unit.parameterTree!.allParameters { values[parameter.address] = parameter.value }
        comparisons = [values, values]
        token = unit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async { self?.values[address] = value }
        })
    }
    deinit { if let token { unit.parameterTree?.removeParameterObserver(token) } }
    func selectComparison(_ slot: Int) {
        guard (0...1).contains(slot), slot != activeSlot else { return }
        refreshAutomation()
        comparisons[activeSlot] = values
        for (address, value) in comparisons[slot] {
            unit.parameterTree?.parameter(withAddress: address)?.setValue(value, originator: token)
        }
        unit.currentPreset = nil
        activeSlot = slot
        refreshAutomation()
    }
    func copyComparison() {
        refreshAutomation()
        comparisons[1 - activeSlot] = values
    }
    func loadPreset(_ preset: AUAudioUnitPreset) {
        unit.currentPreset = preset
        refreshAutomation()
    }
    func refreshAutomation() {
        meters = unit.meterSnapshot
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
            HStack {
                Menu("Factory presets") {
                    ForEach(model.unit.factoryPresets ?? [], id: \.number) { preset in
                        Button(preset.name) { model.loadPreset(preset) }
                    }
                }.frame(width: 180)
                Spacer()
                Picker("Compare", selection: Binding(get: { model.activeSlot }, set: { model.selectComparison($0) })) {
                    Text("A").tag(0)
                    Text("B").tag(1)
                }.pickerStyle(.segmented).frame(width: 130)
                Button(model.activeSlot == 0 ? "Copy A → B" : "Copy B → A") { model.copyComparison() }
                    .help("Copy current settings into the other comparison slot. A/B slots last while this editor is open.")
            }
            HStack(spacing: 18) {
                levelMeter("IN L", value: model.meters.inputLeft)
                levelMeter("IN R", value: model.meters.inputRight)
                levelMeter("OUT L", value: model.meters.outputLeft)
                levelMeter("OUT R", value: model.meters.outputRight)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(String(format: "COMP  −%.1f dB", model.meters.compressorReduction))
                    Text(String(format: "LIMIT −%.1f dB", model.meters.limiterReduction))
                }.font(.system(size: 10, design: .monospaced)).frame(width: 115)
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
        .frame(minWidth: 620, minHeight: 560)
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
                    ParameterValueField(name: spec.name, value: model.binding(spec))
                        .foregroundStyle(accent).frame(width: 72)
                    Text(suffix(spec)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if spec.unit == .hertz {
                    Slider(value: Binding(get: { log10(model.binding(spec).wrappedValue) }, set: {
                        model.binding(spec).wrappedValue = pow(10, $0)
                    }), in: log10(spec.range.lowerBound)...log10(spec.range.upperBound))
                        .accessibilityLabel(spec.name)
                } else {
                    Slider(value: model.binding(spec), in: spec.range).accessibilityLabel(spec.name)
                }
            }.contextMenu {
                Button("Reset to default") { model.binding(spec).wrappedValue = spec.initial }
            }
        }
    }
    private func levelMeter(_ name: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                Spacer()
                Text(value < -60 ? "−∞" : String(format: "%.1f", value))
            }.font(.system(size: 9, design: .monospaced))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(value >= 0 ? Color.red : accent)
                        .frame(width: geometry.size.width * CGFloat(min(1, max(0, (value + 60) / 60))))
                }
            }.frame(height: 5)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(name).accessibilityValue(String(format: "%.1f dBFS", value))
    }
    private func suffix(_ spec: ParameterSpec) -> String {
        switch spec.unit {
        case .decibels: return "dB"
        case .hertz: return "Hz"
        case .milliseconds: return "ms"
        case .ratio: return ":1"
        default: return ""
        }
    }
}

/// Referenced by the extension executable to ensure the framework is loaded.
@_cdecl("SwiftAudioPluginInitialize")
public func SwiftAudioPluginInitialize() {}
#endif
