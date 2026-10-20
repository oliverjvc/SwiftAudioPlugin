import Foundation
import Testing
@testable import DSP

struct SignalQualityTests {
    @Test(arguments: [Float(-24), -23, -22, -20, -18, -17, -16])
    func compressorMatchesSoftKneeCurve(inputDB: Float) {
        let compressor = Compressor(sampleRate: 48000)
        compressor.threshold = -20
        compressor.ratio = 4
        compressor.knee = 6
        compressor.attack = 0.1
        compressor.release = 10
        let input = AudioUtils.dBToLinear(inputDB)
        var buffer = AudioBuffer(samples: [Float](repeating: input, count: 48000), channelCount: 1)
        compressor.process(&buffer)
        let measuredGain = AudioUtils.linearToDB(buffer.samples.last! / input)
        let expected: Float
        if inputDB <= -23 { expected = 0 }
        else if inputDB >= -17 { expected = (-20 - inputDB) * 0.75 }
        else { expected = -0.75 * pow(inputDB + 23, 2) / 12 }
        #expect(abs(measuredGain - expected) < 0.002)
        #expect(measuredGain <= 0.00001)
    }

    @Test func reverbPreDelayIsExactIncludingZero() {
        func impulse(preDelay: Float) -> [Float] {
            let reverb = Reverb(sampleRate: 48000)
            reverb.preDelay = preDelay
            reverb.dryLevel = 0
            reverb.wetLevel = 0.1
            var buffer = AudioBuffer(frameCount: 16000, channelCount: 1)
            buffer.samples[0] = 1
            reverb.process(&buffer)
            return buffer.samples
        }
        let immediate = impulse(preDelay: 0)
        let delayed = impulse(preDelay: 10)
        let first = immediate.firstIndex { abs($0) > 0.00001 }
        #expect(first == Int(1116.0 * 48000 / 44100))
        #expect(delayed.prefix(480).allSatisfy { $0 == 0 })
        #expect(zip(immediate, delayed.dropFirst(480)).allSatisfy { abs($0 - $1) < 0.000001 })
    }

    @Test func limiterProtectsBothChannelsAtChangingLevels() {
        let limiter = Limiter(sampleRate: 48000)
        limiter.ceiling = -1
        let ceiling = AudioUtils.dBToLinear(-1)
        var buffer = AudioBuffer(frameCount: 48000, channelCount: 2)
        for frame in 0..<buffer.frameCount {
            buffer.samples[2 * frame] = Float(sin(Double(frame) * 0.41)) * 4
            buffer.samples[2 * frame + 1] = Float(cos(Double(frame) * 0.37)) * 2
        }
        limiter.process(&buffer)
        #expect(buffer.samples.allSatisfy { $0.isFinite && abs($0) <= ceiling + 0.000001 })
    }
}
