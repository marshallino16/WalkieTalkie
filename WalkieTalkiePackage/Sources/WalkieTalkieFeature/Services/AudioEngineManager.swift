import AVFoundation
import Observation

@MainActor
@Observable
final class AudioEngineManager {
    enum RecordingState {
        case idle
        case recording(progress: Double)
        case processing
    }

    private(set) var recordingState: RecordingState = .idle
    private(set) var isPlaying = false
    private(set) var audioLevel: Float = 0 // 0...1, updated during recording

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private var playbackDelegate: PlaybackDelegate?
    private var rogerPlayer: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?
    private var recordingStart: Date?

    private let maxDuration: TimeInterval = 20.0

    var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    // MARK: - Recording

    func startRecording() async throws -> Bool {
        guard await requestMicrophonePermission() else { return false }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        let audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
        audioRecorder.isMeteringEnabled = true
        audioRecorder.record()

        self.recorder = audioRecorder
        self.recordingURL = tempURL
        self.recordingStart = Date.now
        self.recordingState = .recording(progress: 0)

        print("[Audio] ✅ Recording started (AVAudioRecorder)")

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let start = self.recordingStart else { break }
                let elapsed = Date.now.timeIntervalSince(start)
                let progress = min(elapsed / self.maxDuration, 1.0)
                self.recordingState = .recording(progress: progress)

                // Read audio level for waveform visualization
                if let rec = self.recorder {
                    rec.updateMeters()
                    let db = rec.averagePower(forChannel: 0) // -160...0
                    let normalized = max(0, min(1, (db + 50) / 50)) // map -50..0 to 0..1
                    self.audioLevel = normalized
                }

                if elapsed >= self.maxDuration {
                    _ = self.stopRecording()
                    break
                }
            }
        }

        return true
    }

    /// Stop recording, apply radio effect, and return the processed URL.
    func stopRecording() -> URL? {
        progressTask?.cancel()
        progressTask = nil

        guard let recorder, let url = recordingURL else {
            recordingState = .idle
            return nil
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        self.audioLevel = 0

        print("[Audio] ✅ Recording stopped, duration: \(String(format: "%.1f", duration))s")

        recordingURL = nil
        recordingStart = nil
        recordingState = .idle

        guard duration > 0.3 else { return nil }

        let processedURL = applyRadioEffect(to: url)
        playRogerBeep()
        return processedURL
    }

    // MARK: - Radio Effect (offline post-processing)
    // "Touche" preset: HP 200 Hz, LP 4500 Hz, radioTower 3% — très léger grésillement radio
    private let fxHighPass: Float = 200
    private let fxLowPass: Float = 4500
    private let fxDistortionMix: Float = 3

    private func applyRadioEffect(to inputURL: URL) -> URL? {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        do {
            let inputFile = try AVAudioFile(forReading: inputURL)
            let format = inputFile.processingFormat
            let frameCount = AVAudioFrameCount(inputFile.length)

            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try inputFile.read(into: inputBuffer)

            // Set up offline engine: player → EQ → distortion → mainMixer
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)

            let eq = AVAudioUnitEQ(numberOfBands: 2)
            eq.bands[0].filterType = .highPass
            eq.bands[0].frequency = fxHighPass
            eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowPass
            eq.bands[1].frequency = fxLowPass
            eq.bands[1].bypass = false
            engine.attach(eq)

            let distortion = AVAudioUnitDistortion()
            distortion.loadFactoryPreset(.speechRadioTower)
            distortion.wetDryMix = fxDistortionMix
            engine.attach(distortion)

            engine.connect(player, to: eq, format: format)
            engine.connect(eq, to: distortion, format: format)
            engine.connect(distortion, to: engine.mainMixerNode, format: format)

            // Offline manual rendering
            let maxFrames: AVAudioFrameCount = 4096
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
            try engine.start()

            // Schedule buffer BEFORE calling play
            player.scheduleBuffer(inputBuffer, at: nil, options: [], completionHandler: nil)
            player.play()

            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 32000,
            ]
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)

            guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                                      frameCapacity: maxFrames) else {
                return nil
            }

            // Render until we've processed all input frames (plus a tail for effects)
            let tailFrames: AVAudioFrameCount = 4096 // give effects a tail
            let totalToRender = frameCount + tailFrames
            var rendered: AVAudioFrameCount = 0

            while rendered < totalToRender {
                let framesToRender = min(maxFrames, totalToRender - rendered)
                let status = try engine.renderOffline(framesToRender, to: renderBuffer)

                switch status {
                case .success:
                    if renderBuffer.frameLength > 0 {
                        try outputFile.write(from: renderBuffer)
                    }
                    rendered += framesToRender
                case .insufficientDataFromInputNode:
                    // Player finished but engine might still have tail - write what we have
                    if renderBuffer.frameLength > 0 {
                        try outputFile.write(from: renderBuffer)
                    }
                    rendered += framesToRender
                case .cannotDoInCurrentContext:
                    // Retry
                    continue
                case .error:
                    print("[Audio] ❌ renderOffline error")
                    engine.stop()
                    return nil
                @unknown default:
                    engine.stop()
                    return nil
                }
            }

            engine.stop()
            print("[Audio] ✅ Applied radio effect → \(outputURL.lastPathComponent)")
            return outputURL

        } catch {
            print("[Audio] ❌ applyRadioEffect failed: \(error)")
            return nil
        }
    }

    // MARK: - Synthesized Reaction Sound

    /// Generate a short reaction audio file (AAC/m4a) with given tones
    /// Returns a URL to the generated file
    func synthesizeReaction(tones: [Double]) throws -> URL {
        let sampleRate: Double = 22050
        let toneDuration: Double = 0.08
        let gapDuration: Double = 0.03
        let frameCountPerTone = Int(sampleRate * toneDuration)
        let gapFrames = Int(sampleRate * gapDuration)

        let totalFrames = tones.count * frameCountPerTone + max(0, tones.count - 1) * gapFrames
        var samples = [Float](repeating: 0, count: totalFrames)

        var offset = 0
        for (i, freq) in tones.enumerated() {
            for f in 0..<frameCountPerTone {
                let t = Double(f) / sampleRate
                // Slight envelope to avoid clicks
                let env = envelope(t: t, duration: toneDuration)
                samples[offset + f] = Float(sin(2 * .pi * freq * t) * 0.35 * env)
            }
            offset += frameCountPerTone
            if i < tones.count - 1 {
                offset += gapFrames
            }
        }

        // Write to m4a AAC file
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: sampleRate,
                                             channels: 1,
                                             interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(samples.count))
        else { throw NSError(domain: "Audio", code: -1) }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<samples.count {
            channelData[i] = samples[i]
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)

        return url
    }

    private func envelope(t: Double, duration: Double) -> Double {
        let fadeDuration = 0.01
        if t < fadeDuration {
            return t / fadeDuration
        } else if t > duration - fadeDuration {
            return (duration - t) / fadeDuration
        }
        return 1
    }

    // MARK: - Playback

    func playAudio(url: URL, completion: @escaping () -> Void) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playbackDelegate = PlaybackDelegate(onFinish: { [weak self] in
                self?.isPlaying = false
                completion()
            })
            audioPlayer?.delegate = playbackDelegate
            audioPlayer?.play()
            isPlaying = true
        } catch {
            isPlaying = false
            completion()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    // MARK: - Roger Beep

    private func playRogerBeep() {
        // Synthesize a short "roger" beep (two-tone)
        let sampleRate: Double = 44100
        let duration: Double = 0.15
        let frameCount = Int(sampleRate * duration)

        var samples = [Float](repeating: 0, count: frameCount * 2)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            samples[i] = Float(sin(2 * .pi * 1000 * t) * 0.3)
        }
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            samples[frameCount + i] = Float(sin(2 * .pi * 1400 * t) * 0.3)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("roger.wav")
        writeWAV(samples: samples, sampleRate: sampleRate, to: url)

        rogerPlayer = try? AVAudioPlayer(contentsOf: url)
        rogerPlayer?.play()
    }

    private func writeWAV(samples: [Float], sampleRate: Double, to url: URL) {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<samples.count {
            channelData[i] = samples[i]
        }

        let file = try? AVAudioFile(forWriting: url, settings: format.settings)
        try? file?.write(from: buffer)
    }

    // MARK: - Permissions

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Playback Delegate

private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in onFinish() }
    }
}
