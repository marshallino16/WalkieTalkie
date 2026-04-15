import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FrequencyDetailViewModel {
    let frequency: Frequency
    let cloudKit: CloudKitManager
    let audioEngine: AudioEngineManager
    let userID: String
    let userName: String

    private(set) var messages: [VoiceMessage] = []
    private(set) var members: [FrequencyMember] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var playingMessageID: String?

    private var refreshTimer: Timer?
    private var listenedMessageIDs: Set<String>

    private static func listenedKey(for code: String) -> String { "listened_\(code)" }

    init(frequency: Frequency, cloudKit: CloudKitManager, audioEngine: AudioEngineManager, userID: String, userName: String) {
        self.frequency = frequency
        self.cloudKit = cloudKit
        self.audioEngine = audioEngine
        self.userID = userID
        self.userName = userName
        // Load persisted listened IDs
        let key = Self.listenedKey(for: frequency.code)
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        self.listenedMessageIDs = Set(saved)
    }

    private func saveListenedIDs() {
        let key = Self.listenedKey(for: frequency.code)
        UserDefaults.standard.set(Array(listenedMessageIDs), forKey: key)
    }

    // MARK: - Data Loading

    func startPolling() {
        Task { await loadMessages() }
        Task { await loadMembers() }

        // Poll every 2.5 seconds for members (live indicator) and messages
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadMessages()
                await self?.loadMembers()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func loadMessages() async {
        do {
            let fetched = try await cloudKit.fetchMessages(for: frequency)
            // Filter: only show non-expired, not from self, not already listened
            messages = fetched.filter { msg in
                !msg.isExpired && msg.senderID != userID && !listenedMessageIDs.contains(msg.id)
            }
        } catch {
            // Silent fail, will retry on next poll
        }
    }

    private func loadMembers() async {
        do {
            members = try await cloudKit.fetchMembers(for: frequency)
        } catch {
            // Silent fail
        }
    }

    // MARK: - Quick Reactions

    func sendReaction(_ reaction: QuickReaction) {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                let url = try audioEngine.synthesizeReaction(tones: reaction.tones)
                _ = try await cloudKit.sendVoiceMessage(
                    to: frequency,
                    senderID: userID,
                    senderName: "\(userName) \(reaction.emoji) \(reaction.rawValue)",
                    audioURL: url,
                    duration: 0.5
                )
                print("[CloudKit] ✅ Reaction sent: \(reaction.rawValue)")
            } catch {
                print("[CloudKit] ❌ Reaction send error: \(error)")
            }
        }
    }

    // MARK: - Admin

    var isCreator: Bool { frequency.creatorID == userID }

    func kickMember(_ member: FrequencyMember) async {
        guard isCreator, member.userID != userID else { return }
        do {
            try await cloudKit.kickMember(member)
            members.removeAll { $0.recordName == member.recordName }
            print("[CloudKit] ✅ Kicked member: \(member.displayName)")
        } catch {
            print("[CloudKit] ❌ Kick error: \(error)")
        }
    }

    /// The currently speaking member (if any, other than self)
    var speakingMember: FrequencyMember? {
        members.first { $0.isSpeaking && $0.userID != userID }
    }

    // MARK: - Recording

    func startRecording() async -> Bool {
        do {
            let started = try await audioEngine.startRecording()
            if started {
                // Signal live speaking indicator (30s window, cleared on stop)
                Task.detached { [cloudKit, frequency, userID] in
                    try? await cloudKit.setSpeaking(frequency, userID: userID, until: Date.now.addingTimeInterval(30))
                }
            }
            return started
        } catch {
            return false
        }
    }

    func stopRecordingAndSend() async {
        // Clear speaking indicator immediately
        let freq = frequency
        let uid = userID
        let ck = cloudKit
        Task.detached {
            try? await ck.setSpeaking(freq, userID: uid, until: Optional<Date>.none)
        }

        guard let audioURL = audioEngine.stopRecording() else { return }

        isSending = true
        do {
            let duration = await audioDuration(url: audioURL)
            let msg = try await cloudKit.sendVoiceMessage(
                to: frequency,
                senderID: userID,
                senderName: userName,
                audioURL: audioURL,
                duration: duration
            )
            print("[CloudKit] ✅ Voice message sent: \(msg.id), duration: \(duration)s")
        } catch {
            print("[CloudKit] ❌ Send voice message error: \(error)")
        }
        isSending = false
    }

    // MARK: - Playback

    func playMessage(_ message: VoiceMessage) {
        guard let url = message.audioAssetURL else { return }
        playingMessageID = message.id

        audioEngine.playAudio(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.playingMessageID = nil
                self.listenedMessageIDs.insert(message.id)
                self.saveListenedIDs()
                // Remove from list after listening
                withAnimation(.easeOut(duration: 0.3)) {
                    self.messages.removeAll { $0.id == message.id }
                }
                // Clean up local file
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Helpers

    private func audioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAssetBridge(url: url)
        return await asset.duration
    }
}

// Tiny helper to get audio duration without importing AVFoundation in the ViewModel
import AVFoundation

private struct AVURLAssetBridge {
    let url: URL
    var duration: TimeInterval {
        get async {
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration)
            return duration.map { CMTimeGetSeconds($0) } ?? 0
        }
    }
}
