import AVFoundation
import SwiftUI

/// Short, synthesized sound effects (no external audio assets required).
/// Kept intentionally simple: a handful of sine/square beeps for feedback,
/// not a composed soundtrack — see project notes for that limitation.
final class SoundManager: ObservableObject {
    @AppStorage("isMuted") var isMuted: Bool = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var started = false
    /// Mono format shared by the node connection and every generated buffer —
    /// a mismatch here is what was crashing scheduleBuffer with
    /// "_outputFormat.channelCount == buffer.format.channelCount".
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    enum Effect {
        case select, assign, win, lose, explode

        var frequency: Double {
            switch self {
            case .select: return 660
            case .assign: return 880
            case .win: return 990
            case .lose: return 220
            case .explode: return 110
            }
        }

        var duration: Double {
            switch self {
            case .win: return 0.35
            case .lose: return 0.4
            case .explode: return 0.25
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
            let envelope = Float(1.0 - t / duration) // simple linear fade-out, avoids clicks
            let sample = Float(sin(2.0 * .pi * frequency * t)) * envelope * 0.2
            channel[frame] = sample
        }
        return buffer
    }
}
