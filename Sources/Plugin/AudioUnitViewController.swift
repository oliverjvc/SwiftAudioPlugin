#if os(macOS)
import AudioToolbox
import CoreAudioKit
import SwiftUI
import UniformTypeIdentifiers

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 760))
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 960, height: 760)
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

enum EditorPalette {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let panel = Color(red: 0.09, green: 0.105, blue: 0.125)
    static let accent = Color(red: 0.48, green: 0.89, blue: 0.72)
    static let bands: [Color] = [
        Color(red: 0.98, green: 0.70, blue: 0.35),
        Color(red: 0.92, green: 0.47, blue: 0.43),
        Color(red: 0.66, green: 0.56, blue: 0.96),
        Color(red: 0.30, green: 0.71, blue: 0.95),
        Color(red: 0.48, green: 0.89, blue: 0.72)
    ]
}

/// Keep partially typed values (such as a lone minus sign) out of the DSP.
struct ParameterValueField: View {
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
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .focused($editing)
            .accessibilityLabel("\(name) value")
            .onAppear { draft = formatted() }
            .onSubmit { commit(); editing = false }
            .onChange(of: editing) { focused in if !focused { commit() } }
            .onChange(of: value) { _ in if !editing { draft = formatted() } }
    }
}

struct EditorKnob: View {
    let spec: ParameterSpec
    @Binding var value: Float
    var color = EditorPalette.accent
    var onEditingChanged: (Bool) -> Void
    @State private var origin: Float?
    private var normalized: Float {
        if spec.unit == .hertz {
            return (log10(max(spec.range.lowerBound, value)) - log10(spec.range.lowerBound))
                / (log10(spec.range.upperBound) - log10(spec.range.lowerBound))
        }
        return (value - spec.range.lowerBound) / (spec.range.upperBound - spec.range.lowerBound)
    }
    private func setNormalized(_ position: Float) {
        let bounded = min(1, max(0, position))
        if spec.unit == .hertz {
            value = pow(10, log10(spec.range.lowerBound)
                + bounded * (log10(spec.range.upperBound) - log10(spec.range.lowerBound)))
        } else { value = spec.range.lowerBound + bounded * (spec.range.upperBound - spec.range.lowerBound) }
    }
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Circle().trim(from: 0, to: CGFloat(min(1, max(0, normalized))) * 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Circle().fill(
                    LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(9).overlay(Circle().stroke(Color.white.opacity(0.06)).padding(9))
                Capsule().fill(color).frame(width: 3, height: 12).offset(y: -17)
                    .rotationEffect(.degrees(Double(normalized) * 270 + 90))
            }
            .rotationEffect(.degrees(135))
            .frame(width: 66, height: 66)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 1).onChanged { event in
                if origin == nil { onEditingChanged(true); origin = normalized }
                let precision: Float = NSEvent.modifierFlags.contains(.shift) ? 0.0004 : 0.004
                let delta = Float(event.translation.width - event.translation.height) * precision
                setNormalized((origin ?? normalized) + delta)
            }.onEnded { _ in origin = nil; onEditingChanged(false) })
            .onTapGesture(count: 2) { value = spec.initial }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spec.name)
            .accessibilityValue(String(format: "%.2f", value))
            .accessibilityAdjustableAction { direction in
                setNormalized(normalized + (direction == .increment ? 0.01 : -0.01))
            }
            ParameterValueField(name: spec.name, value: $value)
                .frame(width: 74).foregroundStyle(color)
            Text(spec.name).font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary).lineLimit(1)
            Text(unitSuffix(spec)).font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .help("Drag to adjust. Hold Shift for fine control. Double-click to reset.")
        .contextMenu { Button("Reset to default") { value = spec.initial } }
        .onDisappear { if origin != nil { origin = nil; onEditingChanged(false) } }
    }
}

func unitSuffix(_ spec: ParameterSpec) -> String {
    switch spec.unit {
    case .decibels: return "dB"
    case .hertz: return "Hz"
    case .milliseconds: return "ms"
    case .ratio: return ":1"
    default: return ""
    }
}

struct PluginControls: View {
    @ObservedObject var model: ParameterModel
    @State private var selected = "Equalizer"
    @State private var selectedBand = 0
    @State private var importing = false
    @State private var exporting = false
    @State private var naming = false
    @State private var pendingExport = false
    @State private var presetName = "My preset"
    @State private var exportDocument: EditorPresetDocument?
    @State private var errorMessage: String?
    private let enabledAddresses: [String: AUParameterAddress] = [
        "Equalizer": 45, "Compressor": 15, "Delay": 35, "Reverb": 24, "Limiter": 40
    ]
    var body: some View {
        VStack(spacing: 0) {
            header
            toolbar
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    moduleNavigation
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if selected == "Equalizer" {
                                EqualizerEditor(model: model, selectedBand: $selectedBand)
                            } else {
                                sectionHeading
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 24) {
                                    ForEach(ParameterSpec.all.filter {
                                        $0.group == selected && $0.unit != .boolean
                                    }, id: \.address) { spec in
                                        EditorKnob(spec: spec, value: model.binding(spec)) {
                                            if $0 { model.beginGesture() } else { model.endGesture() }
                                        }
                                    }
                                }.padding(20).background(EditorPalette.panel, in: RoundedRectangle(cornerRadius: 12))
                                HStack(spacing: 24) {
                                    ForEach(ParameterSpec.all.filter {
                                        $0.group == selected && $0.unit == .boolean && $0.address != enabledAddresses[selected]
                                    }, id: \.address) { spec in parameterToggle(spec) }
                                }
                            }
                        }.padding(22)
                    }
                    ioControls
                }
                Divider().overlay(Color.white.opacity(0.04))
                meterBridge
            }
            footer
        }
        .frame(minWidth: 760, minHeight: 640)
        .background(EditorPalette.background)
        .tint(EditorPalette.accent)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in model.refreshAutomation() }
        .onDisappear { model.endGesture() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size < 1_048_576 else { throw EditorPreset.ValidationError.tooLarge }
                let data = try Data(contentsOf: url)
                guard data.count < 1_048_576 else { throw EditorPreset.ValidationError.tooLarge }
                try model.importPreset(JSONDecoder().decode(EditorPreset.self, from: data))
            } catch { errorMessage = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: presetName) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .sheet(isPresented: $naming, onDismiss: {
            if pendingExport { pendingExport = false; exporting = true }
        }) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Save your sound").font(.title2.weight(.semibold))
                Text("Presets include all processing settings and bypass.").foregroundStyle(.secondary)
                TextField("Preset name", text: $presetName).textFieldStyle(.roundedBorder)
                    .onSubmit { if presetName.count <= 80 { prepareExport() } }
                HStack {
                    Button("Cancel") { naming = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Choose file…") { prepareExport() }.keyboardShortcut(.defaultAction)
                        .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || presetName.count > 80)
                }
            }.padding(26).frame(width: 390).preferredColorScheme(.dark)
        }
        .alert("Preset could not be loaded or saved", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path").font(.system(size: 27, weight: .light))
                .foregroundStyle(EditorPalette.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("SWIFT AUDIO").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(3)
                Text("CHANNEL STRIP").font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(2.5).foregroundStyle(.secondary)
            }
            Spacer()
            Text("SHAPE. CONTROL. CREATE.").font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.3).foregroundStyle(.tertiary)
            Button {
                model.set(2, (model.values[2] ?? 0) >= 0.5 ? 0 : 1)
            } label: {
                Label((model.values[2] ?? 0) >= 0.5 ? "BYPASSED" : "BYPASS", systemImage: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background((model.values[2] ?? 0) >= 0.5 ? Color.orange.opacity(0.18) : Color.white.opacity(0.05),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle((model.values[2] ?? 0) >= 0.5 ? Color.orange : Color.secondary)
        }.padding(.horizontal, 24).padding(.vertical, 20)
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            Menu {
                Section("Factory presets") {
                    ForEach(model.unit.factoryPresets ?? [], id: \.number) { preset in
                        Button(preset.name) { model.loadPreset(preset) }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(EditorPalette.accent)
                    Text(model.presetName).lineLimit(1)
                }.frame(width: 180, alignment: .leading)
            }.menuStyle(.borderlessButton).frame(width: 200)
            iconButton("Import preset", symbol: "square.and.arrow.down") { importing = true }
            iconButton("Export preset", symbol: "square.and.arrow.up") {
                presetName = model.presetName == "Custom" ? "My preset" : model.presetName
                naming = true
            }
            Divider().frame(height: 18)
            iconButton("Undo", symbol: "arrow.uturn.backward") { model.undo() }.disabled(!model.canUndo)
            iconButton("Redo", symbol: "arrow.uturn.forward") { model.redo() }.disabled(!model.canRedo)
            Spacer(minLength: 4)
            Picker("Compare", selection: Binding(get: { model.activeSlot }, set: { model.selectComparison($0) })) {
                Text("A").tag(0)
                Text("B").tag(1)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 86)
            Button(model.activeSlot == 0 ? "A → B" : "B → A") { model.copyComparison() }
                .font(.system(size: 11, design: .monospaced))
                .help("Copy all current settings to the other comparison slot.")
        }
        .padding(.horizontal, 24).padding(.vertical, 11)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }
    private var moduleNavigation: some View {
        HStack(spacing: 8) {
            ForEach(ParameterSpec.groups.dropFirst(), id: \.self) { group in
                Button {
                    model.endGesture()
                    selected = group
                } label: {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Circle().fill((model.values[enabledAddresses[group]!] ?? 1) >= 0.5
                                ? EditorPalette.accent : Color.gray).frame(width: 4, height: 4)
                            Text(group == "Equalizer" ? "EQ" : group.uppercased())
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        }.foregroundStyle(selected == group ? Color.white : Color.secondary)
                        Capsule().fill(selected == group ? EditorPalette.accent : .clear).frame(height: 2)
                    }.padding(.top, 18)
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
            }
        }.padding(.horizontal, 22)
    }
    private var sectionHeading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selected).font(.system(size: 23, weight: .medium))
                Text(sectionDescription).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if let spec = ParameterSpec.all.first(where: { $0.address == enabledAddresses[selected] }) {
                parameterToggle(spec)
            }
            Button("Reset") { model.resetGroup(selected) }.font(.system(size: 10))
                .help("Reset this module. Undo restores the previous settings.")
        }
    }
    private var sectionDescription: String {
        switch selected {
        case "Compressor": return "Control dynamics. Preserve the character."
        case "Delay": return "Independent stereo echoes with filtered feedback."
        case "Reverb": return "Add space, depth and stereo width."
        default: return "Set your final sample-peak ceiling."
        }
    }
    private var ioControls: some View {
        HStack(spacing: 32) {
            compactParameter(ParameterSpec.all[0])
            compactParameter(ParameterSpec.all[1])
        }.padding(.horizontal, 22).padding(.vertical, 16).background(Color.white.opacity(0.025))
    }
    private func compactParameter(_ spec: ParameterSpec) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(spec.name.uppercased()).font(.system(size: 9, weight: .semibold, design: .monospaced))
                Spacer()
                ParameterValueField(name: spec.name, value: model.binding(spec)).frame(width: 65)
                    .foregroundStyle(EditorPalette.accent)
                Text("dB").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Slider(value: model.binding(spec), in: spec.range, onEditingChanged: {
                if $0 { model.beginGesture() } else { model.endGesture() }
            }).controlSize(.small).accessibilityLabel(spec.name)
        }
    }
    private var meterBridge: some View {
        VStack(spacing: 16) {
            Text("LEVELS").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                meterPair("IN", left: model.meters.inputLeft, right: model.meters.inputRight)
                meterPair("OUT", left: model.meters.outputLeft, right: model.meters.outputRight)
            }
            Spacer(minLength: 4)
            reductionMeter("COMP", value: model.meters.compressorReduction)
            reductionMeter("LIMIT", value: model.meters.limiterReduction)
            Text("dBFS / PEAK").font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 14).padding(.vertical, 22).frame(width: 112)
            .background(Color.black.opacity(0.12))
    }
    private func meterPair(_ name: String, left: Float, right: Float) -> some View {
        VStack(spacing: 9) {
            Text(name).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                verticalMeter("\(name) left", value: left)
                verticalMeter("\(name) right", value: right)
            }.frame(height: 240)
            Text(max(left, right) < -60 ? "−∞" : String(format: "%.1f", max(left, right)))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(max(left, right) >= 0 ? Color.orange : Color.secondary)
        }
    }
    private func verticalMeter(_ name: String, value: Float) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [Color.orange, EditorPalette.accent],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: geometry.size.height * CGFloat(min(1, max(0, (value + 60) / 60))))
            }
        }.frame(width: 10)
            .accessibilityLabel(name).accessibilityValue(String(format: "%.1f dBFS", value))
    }
    private func reductionMeter(_ name: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "−%.1f", value))
            }.font(.system(size: 9, design: .monospaced))
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(Color.orange.opacity(0.8))
                        .frame(width: geometry.size.width * CGFloat(min(1, max(0, value / 24))))
                }
            }.frame(height: 4)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name) gain reduction").accessibilityValue(String(format: "%.1f dB", value))
    }
    private var footer: some View {
        HStack {
            Text("IN  →  EQ  →  COMP  →  DELAY  →  REVERB  →  OUT  →  LIMIT")
                .font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary)
            Spacer()
            Text("AUDIO UNIT").font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1).foregroundStyle(EditorPalette.accent.opacity(0.7))
        }.padding(.horizontal, 24).padding(.vertical, 12)
    }
    private func parameterToggle(_ spec: ParameterSpec) -> some View {
        Toggle(spec.name, isOn: Binding(get: { model.binding(spec).wrappedValue >= 0.5 }, set: {
            model.binding(spec).wrappedValue = $0 ? 1 : 0
        })).toggleStyle(.switch).controlSize(.mini).fixedSize()
    }
    private func iconButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 20, height: 20) }
            .buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
    private func prepareExport() {
        do {
            exportDocument = EditorPresetDocument(preset: try model.exportPreset(name: presetName))
            pendingExport = true
            naming = false
        } catch { errorMessage = error.localizedDescription }
    }
}

/// Referenced by the extension executable to ensure the framework is loaded.
@_cdecl("SwiftAudioPluginInitialize")
public func SwiftAudioPluginInitialize() {}
#endif
