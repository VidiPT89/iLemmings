import AVFoundation
import SwiftUI

/// Short, synthesized sound effects (no external audio assets required).
final class SoundManager: ObservableObject {
    @AppStorage("isMuted") var isMuted: Bool = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var started = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    enum Effect {
        case select, assign, win, lose, explode, splat, drown

        var frequency: Double {
            switch self {
            case .select: return 660
            case .assign: return 880
            case .win: return 990
            case .lose: return 220
            case .explode: return 110
            case .splat: return 90
            case .drown: return 140
            }
        }

        var duration: Double {
            switch self {
            case .win: return 0.35
            case .lose: return 0.4
            case .explode: return 0.25
            case .splat: return 0.18
            case .drown: return 0.22
            default: return 0.08
            }
        }
    }

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    private func ensureStarted() {
        guard !started else { return }
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    func play(_ effect: Effect) {
        guard !isMuted else { return }
        ensureStarted()
        guard started, let buffer = makeBuffer(frequency: effect.frequency, duration: effect.duration) else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func makeBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = Float(1.0 - t / duration)
            let sample = Float(sin(2.0 * .pi * frequency * t)) * envelope * 0.2
            channel[frame] = sample
        }
        return buffer
    }
}
