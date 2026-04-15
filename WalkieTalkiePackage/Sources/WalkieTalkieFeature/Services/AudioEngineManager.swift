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

        guard duration > 0.3 else {
            recordingState = .idle
            return nil
        }

        // Apply radio crackle effect offline
        let processedURL = applyRadioEffect(to: url)

        playRogerBeep()
        recordingState = .idle

        return processedURL
    }

    // MARK: - Radio Effect (offline post-processing)

    private func applyRadioEffect(to inputURL: URL) -> URL? {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        do {
            let inputFile = try AVAudioFile(forReading: inputURL)
            let format = inputFile.processingFormat
            let frameCount = AVAudioFrameCount(inputFile.length)

            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return inputURL
            }
            try inputFile.read(into: inputBuffer)

            // Set up offline engine
            let engine = AVAudioEngine()

            let player = AVAudioPlayerNode()
            engine.attach(player)

            // EQ: gentle band-pass for radio color (wider range to keep clarity)
            let eq = AVAudioUnitEQ(numberOfBands: 2)
            eq.bands[0].filterType = .highPass
            eq.bands[0].frequency = 200
            eq.bands[0].bypass = false
            eq.bands[1].filterType = .lowPass
            eq.bands[1].frequency = 4000
            eq.bands[1].bypass = false
            engine.attach(eq)

            // Very light distortion for subtle radio texture (voice stays fully clear)
            let distortion = AVAudioUnitDistortion()
            distortion.loadFactoryPreset(.speechRadioTower)
            distortion.wetDryMix = 5
            engine.attach(distortion)

            // Connect: player → EQ → distortion → mainMixer
            engine.connect(player, to: eq, format: format)
            engine.connect(eq, to: distortion, format: format)
            engine.connect(distortion, to: engine.mainMixerNode, format: format)

            // Enable offline manual rendering
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
            try engine.start()

            player.scheduleBuffer(inputBuffer, completionHandler: nil)
            player.play()

            // Write output
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 32000,
            ]
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)

            let renderBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                                 frameCapacity: engine.manualRenderingMaximumFrameCount)!

            var remainingFrames = frameCount
            while remainingFrames > 0 {
                let framesToRender = min(renderBuffer.frameCapacity, remainingFrames)
                let status = try engine.renderOffline(framesToRender, to: renderBuffer)

                switch status {
                case .success:
                    try outputFile.write(from: renderBuffer)
                    remainingFrames -= framesToRender
                case .insufficientDataFromInputNode:
                    remainingFrames -= framesToRender
                case .error, .cannotDoInCurrentContext:
                    print("[Audio] ⚠️ Render error, using original")
                    return inputURL
                @unknown default:
                    return inputURL
                }
            }

            engine.stop()

            // Clean up original
            try? FileManager.default.removeItem(at: inputURL)
            print("[Audio] ✅ Radio effect applied")
            return outputURL

        } catch {
            print("[Audio] ⚠️ Radio effect failed: \(error), using original")
            return inputURL
        }
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
