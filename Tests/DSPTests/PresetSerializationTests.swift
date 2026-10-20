import Foundation
import Testing
@testable import DSP

struct PresetSerializationTests {
    // Independent fixture: every persisted setting differs from its default.
    private let completeJSON = """
    {
      "id": "11A23B45-6789-4ABC-8DEF-0123456789AB",
      "name": "Čuvani preset 🎛", "category": "Test",
      "inputGain": -4.5, "outputGain": 2.5,
      "eqSettings": {
        "outputGain": -2, "isEnabled": false,
        "bands": [
          {"frequency": 70, "gain": 3, "q": 0.7, "type": "Low Shelf", "isEnabled": false},
          {"frequency": 300, "gain": -4, "q": 1.5, "type": "High Shelf", "isEnabled": true},
          {"frequency": 1200, "gain": 5, "q": 2, "type": "Peak", "isEnabled": false},
          {"frequency": 6000, "gain": -2, "q": 0.8, "type": "Low Pass", "isEnabled": true},
          {"frequency": 90, "gain": 1, "q": 1.2, "type": "High Pass", "isEnabled": false},
          {"frequency": 2500, "gain": -3, "q": 3, "type": "Notch", "isEnabled": true}
        ]
      },
      "compressorSettings": {
        "threshold": -27, "ratio": 7, "attack": 3, "release": 240,
        "makeupGain": 4, "knee": 9, "isEnabled": false
      },
      "reverbSettings": {
        "roomSize": 0.8, "damping": 0.2, "width": 0.6,
        "wetLevel": 0.4, "dryLevel": 0.5, "preDelay": 35, "isEnabled": false
      },
      "delaySettings": {
        "delayTimeL": 375, "delayTimeR": 625, "feedback": 0.6,
        "wetLevel": 0.5, "dryLevel": 0.8, "pingPong": true, "isEnabled": false,
        "highCut": 6500, "lowCut": 180, "tempo": 95, "syncEnabled": true,
        "syncDivisionL": 0.125, "syncDivisionR": 0.5
      },
      "limiterSettings": {"ceiling": -1.5, "release": 125, "isEnabled": false}
    }
    """

    // Exact schema produced by the original encoder (no bands or new fields).
    private let legacyJSON = """
    {
      "id": "11A23B45-6789-4ABC-8DEF-0123456789AB",
      "name": "Legacy", "category": "User",
      "eqSettings": {"outputGain": -3, "isEnabled": false},
      "compressorSettings": {
        "threshold": -18, "ratio": 3, "attack": 10, "release": 100,
        "makeupGain": 2, "knee": 8, "isEnabled": true
      },
      "reverbSettings": {
        "roomSize": 0.5, "damping": 0.5, "width": 1,
        "wetLevel": 0.2, "dryLevel": 0.7, "preDelay": 20, "isEnabled": true
      },
      "delaySettings": {
        "delayTimeL": 250, "delayTimeR": 300, "feedback": 0.4,
        "wetLevel": 0.3, "dryLevel": 1, "pingPong": false, "isEnabled": true
      }
    }
    """

    @Test
    func testJSONRoundTripPreservesEveryField() throws {
        let original = Data(completeJSON.utf8)
        let decoded = try JSONDecoder().decode(PluginPreset.self, from: original)
        let encoded = try JSONEncoder().encode(decoded)
        #expect(try jsonObject(encoded) == jsonObject(original))
        let roundTrip = try JSONDecoder().decode(PluginPreset.self, from: encoded)
        #expect(try jsonObject(JSONEncoder().encode(roundTrip)) == jsonObject(original))
    }

    @Test
    func testPropertyListRoundTrip() throws {
        let preset = try completePreset()
        let encoded = try PropertyListEncoder().encode(preset)
        let decoded = try PropertyListDecoder().decode(PluginPreset.self, from: encoded)
        #expect(try jsonObject(JSONEncoder().encode(decoded)) == jsonObject(Data(completeJSON.utf8)))
    }

    @Test
    func testLoadAppliesEverySettingAndPreservesRuntimeState() throws {
        let engine = PluginEngine(sampleRate: 48000)
        let existingBand = engine.eq.bands[0]
        engine.isBypassed = true
        engine.inputLevelL = -12
        engine.outputLevelR = -15
        let preset = try completePreset()
        let count = engine.presets.count
        engine.loadPreset(preset)

        #expect(engine.currentPreset?.id == preset.id)
        #expect(engine.presets.count == count)
        #expect(engine.isBypassed)
        #expect(engine.sampleRate == 48000)
        #expect(engine.inputLevelL == -12)
        #expect(engine.outputLevelR == -15)
        #expect(engine.inputGain == -4.5)
        #expect(engine.outputGain == 2.5)
        #expect(engine.eq.bands[0] === existingBand)
        #expect(engine.eq.bands.count == 6)
        #expect(engine.eq.outputGain == -2)
        #expect(!engine.eq.isEnabled)
        for (index, band) in engine.eq.bands.enumerated() {
            let expected = preset.eqSettings.bands[index]
            #expect(band.frequency == expected.frequency)
            #expect(band.gain == expected.gain)
            #expect(band.q == expected.q)
            #expect(band.type.rawValue == expected.type)
            #expect(band.isEnabled == preset.eqSettings.bandEnabled[index])
        }
        #expect(engine.compressor.threshold == -27)
        #expect(engine.compressor.ratio == 7)
        #expect(engine.compressor.attack == 3)
        #expect(engine.compressor.release == 240)
        #expect(engine.compressor.makeupGain == 4)
        #expect(engine.compressor.knee == 9)
        #expect(!engine.compressor.isEnabled)
        #expect(engine.reverb.roomSize == 0.8)
        #expect(engine.reverb.damping == 0.2)
        #expect(engine.reverb.width == 0.6)
        #expect(engine.reverb.wetLevel == 0.4)
        #expect(engine.reverb.dryLevel == 0.5)
        #expect(engine.reverb.preDelay == 35)
        #expect(!engine.reverb.isEnabled)
        #expect(engine.delay.delayTimeL == 375)
        #expect(engine.delay.delayTimeR == 625)
        #expect(engine.delay.feedback == 0.6)
        #expect(engine.delay.wetLevel == 0.5)
        #expect(engine.delay.dryLevel == 0.8)
        #expect(engine.delay.pingPong)
        #expect(!engine.delay.isEnabled)
        #expect(engine.delay.highCut == 6500)
        #expect(engine.delay.lowCut == 180)
        #expect(engine.delay.tempo == 95)
        #expect(engine.delay.syncEnabled)
        #expect(engine.delay.syncDivisionL == 0.125)
        #expect(engine.delay.syncDivisionR == 0.5)
        #expect(engine.limiter.ceiling == -1.5)
        #expect(engine.limiter.release == 125)
        #expect(!engine.limiter.isEnabled)
    }

    @Test
    func testSaveEncodeDecodeLoadRoundTrip() throws {
        let source = PluginEngine()
        let preset = try completePreset()
        source.loadPreset(preset)
        let count = source.presets.count
        let saved = source.saveCurrentAsPreset(name: preset.name, category: preset.category)
        #expect(saved.id != preset.id)
        #expect(source.presets.count == count + 1)
        #expect(source.presets.last?.id == saved.id)
        #expect(source.currentPreset?.id == saved.id)

        var expected = preset
        expected.id = saved.id
        #expect(try jsonObject(JSONEncoder().encode(saved)) == jsonObject(JSONEncoder().encode(expected)))
        let decoded = try JSONDecoder().decode(PluginPreset.self, from: JSONEncoder().encode(saved))
        let destination = PluginEngine()
        destination.loadPreset(decoded)
        var resaved = destination.saveCurrentAsPreset(name: saved.name, category: saved.category)
        resaved.id = saved.id
        #expect(try jsonObject(JSONEncoder().encode(resaved)) == jsonObject(JSONEncoder().encode(saved)))

        // A saved preset owns values, not live references to processors.
        source.eq.bands[0].gain = 12
        source.delay.tempo = 160
        #expect(saved.eqSettings.bands[0].gain == 3)
        #expect(saved.delaySettings.tempo == 95)
    }

    @Test
    func testLegacyPresetDefaultsAndReencoding() throws {
        let preset = try JSONDecoder().decode(PluginPreset.self, from: Data(legacyJSON.utf8))
        #expect(preset.name == "Legacy")
        #expect(preset.eqSettings.bands.map { $0.frequency } == [80, 250, 1000, 4000, 12000])
        #expect(preset.eqSettings.bands.allSatisfy { $0.gain == 0 && $0.q == 1 })
        #expect(preset.inputGain == 0)
        #expect(preset.outputGain == 0)
        #expect(preset.delaySettings.highCut == 8000)
        #expect(preset.delaySettings.lowCut == 100)
        #expect(preset.delaySettings.tempo == 120)
        #expect(!preset.delaySettings.syncEnabled)
        #expect(preset.delaySettings.syncDivisionL == 0.25)
        #expect(preset.delaySettings.syncDivisionR == 0.25)
        #expect(preset.limiterSettings.ceiling == -0.3)
        #expect(preset.limiterSettings.release == 50)
        #expect(preset.limiterSettings.isEnabled)
        let engine = PluginEngine()
        engine.loadPreset(try completePreset())
        engine.loadPreset(preset)
        #expect(engine.eq.bands.count == 5)
        #expect(engine.eq.bands.allSatisfy { $0.type == .peak && $0.isEnabled })
        #expect(engine.eq.outputGain == -3)
        #expect(!engine.eq.isEnabled)
        #expect(engine.inputGain == 0)
        #expect(engine.outputGain == 0)
        #expect(engine.compressor.threshold == -18)
        #expect(engine.compressor.knee == 8)
        #expect(engine.compressor.isEnabled)
        #expect(engine.reverb.isEnabled)
        #expect(engine.delay.isEnabled)
        #expect(engine.limiter.isEnabled)
        let encoded = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(PluginPreset.self, from: encoded)
        #expect(try jsonObject(JSONEncoder().encode(decoded)) == jsonObject(encoded))
    }

    @Test
    func testBandCompatibilityAndEmptyBands() throws {
        let json = """
        {"outputGain": 0, "isEnabled": true, "bands": [
          {"frequency": 900, "gain": 3, "q": 1.5, "type": "peak"},
          {"frequency": 400, "gain": -2, "q": 2, "type": "Future Filter"}
        ]}
        """
        var preset = PluginPreset(name: "Compatibility")
        preset.eqSettings = try JSONDecoder().decode(EQPresetData.self, from: Data(json.utf8))
        #expect(preset.eqSettings.bandEnabled == [true, true])
        let engine = PluginEngine()
        engine.loadPreset(preset)
        #expect(engine.eq.bands.map { $0.type } == [.peak, .peak])
        // An explicitly empty array is distinct from the missing legacy field.
        preset.eqSettings.bands = []
        let encoded = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(PluginPreset.self, from: encoded)
        #expect(decoded.eqSettings.bands.isEmpty)
        #expect(decoded.eqSettings.bandEnabled.isEmpty)
        engine.loadPreset(decoded)
        #expect(engine.eq.bands.isEmpty)
    }

    @Test
    func testTupleAPIWithMissingEnabledEntries() throws {
        var settings = EQPresetData()
        settings.bands = [(400, 2, 1.2, "Peak"), (3000, -3, 2, "Notch")]
        settings.bandEnabled = [false]
        let decoded = try JSONDecoder().decode(EQPresetData.self, from: JSONEncoder().encode(settings))
        #expect(decoded.bandEnabled == [false, true])
        #expect(decoded.bands.count == 2)
        #expect(decoded.bands[1].type == "Notch")
    }

    @Test
    func testLoadedEQCoefficientsUseDestinationSampleRate() throws {
        for rate in [44100.0, 48000.0, 96000.0, 192000.0] {
            for type in EQBandType.allCases {
                let engine = PluginEngine(sampleRate: rate)
                var preset = PluginPreset(name: "Coefficients")
                preset.eqSettings.bands = [(1700, 8, 1.7, type.rawValue)]
                let decoded = try JSONDecoder().decode(PluginPreset.self, from: JSONEncoder().encode(preset))
                engine.loadPreset(decoded)
                let reference = EQBand(frequency: 1700, gain: 8, q: 1.7, type: type)
                reference.setSampleRate(rate)
                for frame in 0..<64 {
                    let input: Float = frame == 0 ? 0.5 : 0
                    let expected = reference.processSample(left: input, right: -input)
                    let actual = engine.eq.bands[0].processSample(left: input, right: -input)
                    #expect(abs(actual.0 - expected.0) <= 0.000001)
                    #expect(abs(actual.1 - expected.1) <= 0.000001)
                }
            }
        }
    }

    @Test
    func testMalformedValuesAreNotSilentlyDefaulted() throws {
        let invalidGain = completeJSON.replacingOccurrences(of: "\"inputGain\": -4.5",
                                                           with: "\"inputGain\": \"bad\"")
        let invalidDelay = completeJSON.replacingOccurrences(of: "\"tempo\": 95",
                                                            with: "\"tempo\": \"bad\"")
        let invalidBand = completeJSON.replacingOccurrences(of: "\"q\": 0.7",
                                                           with: "\"q\": \"bad\"")
        for json in [invalidGain, invalidDelay, invalidBand] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(PluginPreset.self, from: Data(json.utf8))
            }
        }
    }

    private func completePreset() throws -> PluginPreset {
        try JSONDecoder().decode(PluginPreset.self, from: Data(completeJSON.utf8))
    }

    private func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }
}
