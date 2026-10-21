#if os(macOS)
import AudioToolbox
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Portable AU editor presets use stable identifiers, never parameter-array order.
/// Separate from PluginPreset: the AU exposes a fixed 50-parameter contract.
struct EditorPreset: Codable {
    var format = "com.oliverjvc.SwiftAudioPlugin.editor-preset"
    var version = 1
    var name: String
    var parameters: [String: Float]

    enum ValidationError: LocalizedError {
        case unsupportedFormat, invalidName, invalidParameter(String), tooLarge
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "This file is not a supported Swift Audio editor preset."
            case .invalidName: return "Give the preset a name between 1 and 80 characters."
            case .invalidParameter(let name): return "The preset has a missing or invalid value for \(name)."
            case .tooLarge: return "Preset files must be smaller than 1 MB."
            }
        }
    }

    func validatedValues() throws -> [AUParameterAddress: Float] {
        guard format == "com.oliverjvc.SwiftAudioPlugin.editor-preset", version == 1 else {
            throw ValidationError.unsupportedFormat
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { throw ValidationError.invalidName }
        var values: [AUParameterAddress: Float] = [:]
        for spec in ParameterSpec.all {
            guard let value = parameters[spec.identifier], value.isFinite,
                  spec.range.contains(value),
                  spec.unit != .boolean || value == 0 || value == 1 else {
                throw ValidationError.invalidParameter(spec.name)
            }
            values[spec.address] = value
        }
        return values
    }
}

struct EditorPresetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var preset: EditorPreset

    init(preset: EditorPreset) { self.preset = preset }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard data.count < 1_048_576 else { throw EditorPreset.ValidationError.tooLarge }
        preset = try JSONDecoder().decode(EditorPreset.self, from: data)
        _ = try preset.validatedValues()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        _ = try preset.validatedValues()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(preset))
    }
}

final class ParameterModel: ObservableObject {
    let unit: SwiftAudioUnit
    @Published var values: [AUParameterAddress: Float] = [:]
    @Published var activeSlot = 0
    @Published var meters: MeterSnapshot
    @Published private(set) var presetName = "Default"
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    private var comparisons: [[AUParameterAddress: Float]] = []
    private var token: AUParameterObserverToken?
    private struct Snapshot: Equatable {
        var values: [AUParameterAddress: Float]
        var slot: Int
        var comparisons: [[AUParameterAddress: Float]]
        var name: String
    }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var gesture: Snapshot?
    private let historyLimit = 100

    init(unit: SwiftAudioUnit) {
        self.unit = unit
        self.meters = unit.meterSnapshot
        for parameter in unit.parameterTree!.allParameters { values[parameter.address] = parameter.value }
        comparisons = [values, values]
        presetName = unit.currentPreset?.name ?? "Custom"
        token = unit.parameterTree?.token(byAddingParameterObserver: { [weak self] _, _ in
            // Read the latest atomic values, not queued values that may already be stale.
            DispatchQueue.main.async { self?.refreshAutomation() }
        })
    }
    deinit { if let token { unit.parameterTree?.removeParameterObserver(token) } }

    private var snapshot: Snapshot {
        Snapshot(values: values, slot: activeSlot, comparisons: comparisons, name: presetName)
    }
    private func updateHistoryAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    private func record(_ before: Snapshot) {
        guard before != snapshot else { return }
        undoStack.append(before)
        if undoStack.count > historyLimit { undoStack.removeFirst() }
        redoStack.removeAll()
        updateHistoryAvailability()
    }
    /// Slider, knob and EQ-node drags create one undo step for the entire gesture.
    func beginGesture() {
        guard gesture == nil else { return }
        refreshAutomation()
        gesture = snapshot
    }
    func endGesture() {
        guard let before = gesture else { return }
        gesture = nil
        refreshAutomation()
        record(before)
    }
    private func change(_ action: () -> Void) {
        endGesture()
        refreshAutomation()
        let before = snapshot
        action()
        refreshAutomation()
        record(before)
    }
    private func restore(_ state: Snapshot) {
        for (address, value) in state.values {
            unit.parameterTree?.parameter(withAddress: address)?.setValue(value, originator: token)
        }
        unit.currentPreset = nil
        activeSlot = state.slot
        comparisons = state.comparisons
        refreshAutomation()
        presetName = state.name
    }
    func undo() {
        endGesture()
        refreshAutomation()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        restore(previous)
        updateHistoryAvailability()
    }
    func redo() {
        endGesture()
        refreshAutomation()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        restore(next)
        updateHistoryAvailability()
    }
    func selectComparison(_ slot: Int) {
        guard (0...1).contains(slot), slot != activeSlot else { return }
        change {
            comparisons[activeSlot] = values
            for (address, value) in comparisons[slot] {
                unit.parameterTree?.parameter(withAddress: address)?.setValue(value, originator: token)
            }
            unit.currentPreset = nil
            activeSlot = slot
            refreshAutomation()
            presetName = "Comparison \(slot == 0 ? "A" : "B")"
        }
    }
    func copyComparison() {
        change { comparisons[1 - activeSlot] = values }
    }
    func loadPreset(_ preset: AUAudioUnitPreset) {
        change {
            unit.currentPreset = preset
            presetName = preset.name
        }
    }
    func resetGroup(_ group: String) {
        change {
            for spec in ParameterSpec.all where spec.group == group {
                unit.parameterTree?.parameter(withAddress: spec.address)?.setValue(spec.initial, originator: token)
            }
            unit.currentPreset = nil
            presetName = "Custom"
        }
    }
    func refreshAutomation() {
        meters = unit.meterSnapshot
        // Scheduled render events update atomics without invoking observers on the render thread.
        var latest = values
        for parameter in unit.parameterTree!.allParameters { latest[parameter.address] = parameter.value }
        if values != latest {
            values = latest
            presetName = unit.currentPreset?.name ?? "Custom"
        }
    }
    func binding(_ spec: ParameterSpec) -> Binding<Float> {
        Binding(get: { self.values[spec.address] ?? spec.initial }, set: { value in
            let bounded = spec.bounded(value)
            guard self.values[spec.address] != bounded else { return }
            let write = {
                self.unit.currentPreset = nil
                self.values[spec.address] = bounded
                self.unit.parameterTree?.parameter(withAddress: spec.address)?.setValue(bounded, originator: self.token)
                self.presetName = "Custom"
            }
            if self.gesture != nil { write() } else { self.change(write) }
        })
    }
    func set(_ address: AUParameterAddress, _ value: Float) {
        guard let spec = ParameterSpec.all.first(where: { $0.address == address }) else { return }
        binding(spec).wrappedValue = value
    }
    func exportPreset(name: String) throws -> EditorPreset {
        refreshAutomation()
        let parameters = Dictionary(uniqueKeysWithValues: ParameterSpec.all.map {
            ($0.identifier, values[$0.address] ?? $0.initial)
        })
        let preset = EditorPreset(name: name.trimmingCharacters(in: .whitespacesAndNewlines), parameters: parameters)
        _ = try preset.validatedValues()
        return preset
    }
    func importPreset(_ preset: EditorPreset) throws {
        // Validate the whole file before touching any host parameter.
        let decoded = try preset.validatedValues()
        change {
            for (address, value) in decoded {
                unit.parameterTree?.parameter(withAddress: address)?.setValue(value, originator: token)
            }
            unit.currentPreset = nil
            // Refresh before assigning the display name so observer polling preserves it.
            refreshAutomation()
            presetName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
#endif
