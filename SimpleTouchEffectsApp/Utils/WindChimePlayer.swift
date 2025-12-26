import Foundation
import AVFoundation

final class WindChimePlayer {
    static let shared = WindChimePlayer()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let poolSize = 4
    private let audioQueue = DispatchQueue(label: "WindChimePlayer.generate", qos: .userInitiated)
    private var continuousTimer: DispatchSourceTimer?
    private var isContinuous = false
    private let continuousInterval: TimeInterval = 0.18
    private var noteTimers: [Int: DispatchSourceTimer] = [:]

    private init() {
        // create and attach a small pool of player nodes to avoid attach/detach on each play
        // use the main mixer's output format so buffers match channel count
        let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            players.append(node)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: mixerFormat)
        }

        do {
            try engine.start()
        } catch {
            print("WindChimePlayer: engine start error: \(error)")
        }
    }

    func playChime() {
        // generate buffer off the main thread to avoid UI jank
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            let duration: Double = 1.2
            // match sample rate and channel count to main mixer's output
            let mixerFormat = self.engine.mainMixerNode.outputFormat(forBus: 0)
            let sampleRate: Double = mixerFormat.sampleRate
            let channels: AVAudioChannelCount = mixerFormat.channelCount
            let frameCount = AVAudioFrameCount(sampleRate * duration)
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else { return }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount

            let baseFreq = 420.0 + Double(arc4random_uniform(400))
            let partials: [Double] = [1.0, 2.01, 2.9, 3.8]
            let partialAmps: [Double] = [1.0, 0.5, 0.28, 0.14]
            let decay = 2.2 + Double(arc4random_uniform(100)) / 100.0

            // fill all channels (non-interleaved) with same synthesized data
            let channelCount = Int(channels)
            for chIndex in 0..<channelCount {
                let chPtr = buffer.floatChannelData![chIndex]
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / sampleRate
                    let env = exp(-t * decay)
                    var sample: Double = 0
                    for (idx, p) in partials.enumerated() {
                        let freq = baseFreq * p * (1.0 + (Double(arc4random_uniform(100)) / 10000.0))
                        sample += partialAmps[idx] * sin(2.0 * .pi * freq * t + 0.2 * sin(2.0 * .pi * 0.5 * t))
                    }
                    sample *= env * 0.25
                    chPtr[i] = Float(sample)
                }
            }

            // schedule on main thread to interact safely with AVAudioEngine
            DispatchQueue.main.async {
                let player = self.players[self.nextPlayer]
                self.nextPlayer = (self.nextPlayer + 1) % self.poolSize

                player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                if !player.isPlaying {
                    player.play()
                }
            }
        }
    }

    // generate a PCM buffer synchronously on the calling queue
    private func generateBuffer(duration: Double) -> AVAudioPCMBuffer? {
        let mixerFormat = self.engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = mixerFormat.sampleRate
        let channels = mixerFormat.channelCount
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels) else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let baseFreq = 420.0 + Double(arc4random_uniform(400))
        let partials: [Double] = [1.0, 2.01, 2.9, 3.8]
        let partialAmps: [Double] = [1.0, 0.5, 0.28, 0.14]
        let decay = 2.2 + Double(arc4random_uniform(100)) / 100.0

        let channelCount = Int(channels)
        for chIndex in 0..<channelCount {
            let chPtr = buffer.floatChannelData![chIndex]
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let env = exp(-t * decay)
                var sample: Double = 0
                for (idx, p) in partials.enumerated() {
                    let freq = baseFreq * p * (1.0 + (Double(arc4random_uniform(100)) / 10000.0))
                    sample += partialAmps[idx] * sin(2.0 * .pi * freq * t + 0.2 * sin(2.0 * .pi * 0.5 * t))
                }
                sample *= env * 0.25
                chPtr[i] = Float(sample)
            }
        }

        return buffer
    }

    // MARK: - Continuous chime control
    func startContinuous() {
        DispatchQueue.main.async {
            if self.isContinuous { return }
            self.isContinuous = true
            self.continuousTimer = DispatchSource.makeTimerSource(queue: self.audioQueue)
            self.continuousTimer?.schedule(deadline: .now(), repeating: self.continuousInterval)
            self.continuousTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }
                if let buffer = self.generateBuffer(duration: 0.35) {
                    DispatchQueue.main.async {
                        let player = self.players[self.nextPlayer]
                        self.nextPlayer = (self.nextPlayer + 1) % self.poolSize
                        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                        if !player.isPlaying {
                            player.play()
                        }
                    }
                }
            }
            self.continuousTimer?.resume()
        }
    }

    func stopContinuous() {
        DispatchQueue.main.async {
            guard self.isContinuous else { return }
            self.isContinuous = false
            if let t = self.continuousTimer {
                t.cancel()
                self.continuousTimer = nil
            }
            for p in self.players {
                if p.isPlaying { p.stop() }
            }
        }
    }

    // MARK: - Per-node note control
    func startNote(id: Int, interval: TimeInterval? = nil) {
        let interval = interval ?? continuousInterval
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if self.noteTimers[id] != nil { return }
            let timer = DispatchSource.makeTimerSource(queue: self.audioQueue)
            timer.schedule(deadline: .now(), repeating: interval)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                if let buffer = self.generateBuffer(duration: 0.35) {
                    DispatchQueue.main.async {
                        let player = self.players[self.nextPlayer]
                        self.nextPlayer = (self.nextPlayer + 1) % self.poolSize
                        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
                        if !player.isPlaying { player.play() }
                    }
                }
            }
            self.noteTimers[id] = timer
            timer.resume()
        }
    }

    func stopNote(id: Int) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if let t = self.noteTimers[id] {
                t.cancel()
                self.noteTimers.removeValue(forKey: id)
            }
            // do not forcibly stop players here; allow scheduled buffers to complete
        }
    }
}
