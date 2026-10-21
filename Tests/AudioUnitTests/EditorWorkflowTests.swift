#if os(macOS)
import AudioToolbox
import Foundation
import Testing
@testable import AudioUnitPlugin

struct EditorWorkflowTests {
    private func makeUnit() throws -> SwiftAudioUnit {
        try SwiftAudioUnit(componentDescription: SwiftAudioPluginFactory.componentDescription)
    }

    @Test @MainActor func dragIsOneUndoStepForSeveralParameters() throws {
        let unit = try makeUnit()
        let model = ParameterModel(unit: unit)
        model.beginGesture()
        for value: Float in [200, 500, 800] { model.set(50, value) }
        model.set(51, 6)
        model.endGesture()
        #expect(model.canUndo)
        model.undo()
        #expect(model.values[50] == 80)
        #expect(model.values[51] == 0)
        #expect(!model.canUndo)
        #expect(model.canRedo)
        model.redo()
        #expect(model.values[50] == 800)
        #expect(model.values[51] == 6)
        #expect(!model.canRedo)
    }

    @Test @MainActor func noOpAndNewEditsHandleRedoCorrectly() throws {
        let model = ParameterModel(unit: try makeUnit())
        model.set(1, 0)
        model.beginGesture()
        model.endGesture()
        #expect(!model.canUndo)
        model.set(1, -3)
        model.undo()
        #expect(model.canRedo)
        model.set(1, -6)
        #expect(!model.canRedo)
        model.undo()
        #expect(model.values[1] == 0)
    }

    @Test @MainActor func groupResetAndFactoryPresetAreUndoable() throws {
        let unit = try makeUnit()
        let model = ParameterModel(unit: unit)
        model.set(51, 8)
        model.set(10, -35)
        model.resetGroup("Equalizer")
        #expect(model.values[51] == 0)
        #expect(model.values[10] == -35)
        model.undo()
        #expect(model.values[51] == 8)
        model.loadPreset(unit.factoryPresets![3])
        #expect(model.values[20] == 0.8)
        model.undo()
        #expect(model.values[51] == 8)
        #expect(model.values[10] == -35)
        model.redo()
        #expect(model.values[20] == 0.8)
        #expect(model.presetName == "Ambient Pad")
    }

    @Test @MainActor func automationIsCapturedBeforeUndoCheckpoint() throws {
        let unit = try makeUnit()
        let model = ParameterModel(unit: unit)
        unit.parameterTree!.parameter(withAddress: 1)!.value = -12
        model.set(51, 5)
        model.undo()
        #expect(unit.parameterTree!.parameter(withAddress: 1)!.value == -12)
        #expect(model.values[51] == 0)
    }

    @Test @MainActor func historyIsBounded() throws {
        let model = ParameterModel(unit: try makeUnit())
        for index in 1...130 { model.set(51, index.isMultiple(of: 2) ? 3 : 6) }
        var steps = 0
        while model.canUndo { model.undo(); steps += 1 }
        #expect(steps == 100)
        #expect(model.values[51] == 3)
    }

    @Test @MainActor func comparisonCopyAndSwitchCanBeUndone() throws {
        let model = ParameterModel(unit: try makeUnit())
        model.set(1, -3)
        model.copyComparison()
        model.selectComparison(1)
        model.set(1, -9)
        model.undo()
        #expect(model.values[1] == -3)
        model.undo()
        #expect(model.activeSlot == 0)
        #expect(model.values[1] == -3)
        model.redo()
        #expect(model.activeSlot == 1)
        #expect(model.values[1] == -3)
        model.selectComparison(0)
        #expect(model.values[1] == -3)
    }

    @Test @MainActor func userPresetRoundTripAndImportUndo() throws {
        let source = ParameterModel(unit: try makeUnit())
        for spec in ParameterSpec.all { source.set(spec.address, spec.range.upperBound) }
        let preset = try source.exportPreset(name: "  Glas 🎛  ")
        #expect(preset.name == "Glas 🎛")
        #expect(preset.parameters.count == 50)
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(EditorPreset.self, from: data)
        let destination = ParameterModel(unit: try makeUnit())
        try destination.importPreset(decoded)
        let imported = try destination.exportPreset(name: decoded.name)
        #expect(imported.parameters == preset.parameters)
        #expect(destination.presetName == "Glas 🎛")
        destination.refreshAutomation()
        #expect(destination.presetName == "Glas 🎛")
        destination.undo()
        #expect(destination.values[51] == 0)
        destination.redo()
        #expect(destination.values[51] == 24)
        #expect(destination.presetName == "Glas 🎛")
    }

    @Test @MainActor func invalidImportsNeverPartiallyApply() throws {
        let model = ParameterModel(unit: try makeUnit())
        model.set(1, -4)
        let valid = try model.exportPreset(name: "Valid")
        let before = model.values
        var variants: [EditorPreset] = []
        var preset = valid
        preset.version = 99
        variants.append(preset)
        preset = valid; preset.format = "another.plugin"
        variants.append(preset)
        preset = valid; preset.name = "   "
        variants.append(preset)
        preset = valid; preset.parameters["eq0Q"] = nil
        variants.append(preset)
        preset = valid; preset.parameters["eq0Q"] = .nan
        variants.append(preset)
        preset = valid; preset.parameters["eq0Q"] = 0
        variants.append(preset)
        preset = valid; preset.parameters["bypass"] = 0.4
        variants.append(preset)
        for invalid in variants {
            #expect(throws: (any Error).self) { try model.importPreset(invalid) }
            #expect(model.values == before)
        }
        model.undo()
        #expect(model.values[1] == 0) // Invalid imports did not pollute undo history.
    }
}
#endif
