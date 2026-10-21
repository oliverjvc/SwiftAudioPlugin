import Foundation
import Testing
@testable import DSP

struct EQResponseTests {
    @Test(arguments: EQBandType.allCases)
    func plottedMagnitudeMatchesRenderedImpulse(type: EQBandType) {
        for rate in [44100.0, 48000, 96000, 192000] {
            let band = EQBand(frequency: 1000, gain: 6, q: 1.3, type: type)
            band.setSampleRate(rate)
            let frequencies = [120.0, 1000, 7000]
            var real = [Double](repeating: 0, count: frequencies.count)
            var imaginary = real
            for frame in 0..<16384 {
                let sample = Double(band.processSample(left: frame == 0 ? 1 : 0, right: 0).0)
                for index in frequencies.indices {
                    let phase = 2 * Double.pi * frequencies[index] * Double(frame) / rate
                    real[index] += sample * cos(phase)
                    imaginary[index] -= sample * sin(phase)
                }
            }
            for index in frequencies.indices {
                let measured = sqrt(real[index] * real[index] + imaginary[index] * imaginary[index])
                let plotted = Double(band.magnitudeResponse(at: Float(frequencies[index])))
                #expect(abs(measured - plotted) < 0.0005)
            }
        }
    }

    @Test func disabledBandIsUnityAndQueriesDoNotAdvanceHistory() {
        let plotted = EQBand(frequency: 1800, gain: 9, q: 2)
        let reference = EQBand(frequency: 1800, gain: 9, q: 2)
        for frame in 0..<128 {
            _ = plotted.magnitudeResponse(at: Float(frame + 20))
            let input: Float = frame == 0 ? 1 : 0
            let actual = plotted.processSample(left: input, right: -input)
            let expected = reference.processSample(left: input, right: -input)
            #expect(actual.0 == expected.0 && actual.1 == expected.1)
        }
        plotted.isEnabled = false
        #expect(plotted.magnitudeResponse(at: 1800) == 1)
        #expect(plotted.magnitudeResponse(at: .nan) == 1)
    }

    @Test func peakCenterReflectsBoostAndSampleRate() {
        for rate in [44100.0, 48000, 96000, 192000] {
            let band = EQBand(frequency: 1700, gain: 8, q: 1.7)
            band.setSampleRate(rate)
            let db = 20 * log10(band.magnitudeResponse(at: 1700))
            #expect(abs(db - 8) < 0.001)
        }
    }
}
