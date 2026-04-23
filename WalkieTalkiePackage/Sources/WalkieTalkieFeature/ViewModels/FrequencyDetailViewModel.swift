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
    private(set) var bans: [FrequencyBan] = []
    private(set) var removalReason: RemovalReason?

    enum RemovalReason: Equatable {
        case kicked
        case banned
    }

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

    private func loadBans() async {
        do {
            bans = try await cloudKit.fetchBans(for: frequency)
        } catch {
            // Silent fail
        }
    }

    func startPolling() {
        Task { await loadMessages() }
        Task { await loadMembers() }
        Task { await loadBans() }

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
            let fetched = try await cloudKit.fetchMembers(for: frequency)
            members = fetched
            // Only check removal if user is missing from the returned page.
            // The member list may be incomplete (CloudKit returns max ~100 results),
            // so we do a targeted query to confirm before showing the kick overlay.
            if !fetched.isEmpty && !fetched.contains(where: { $0.userID == userID }) {
                let stillMember = try await cloudKit.isUserMember(userID: userID, of: frequency)
                if !stillMember {
                    stopPolling()
                    let isBanned = (try? await cloudKit.isUserBanned(userID: userID, from: frequency)) ?? false
                    removalReason = isBanned ? .banned : .kicked
                }
            }
        } catch {
            // Silent fail — don't trigger removal on network errors
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
                Log.cloudkit.info("Reaction sent: \(reaction.rawValue, privacy: .public)")
            } catch {
                Log.cloudkit.error("Reaction send error: \(error, privacy: .public)")
            }
        }
    }

    // MARK: - Admin

    var isCreator: Bool { frequency.creatorID == userID }

    var currentUserRole: MemberRole {
        members.first(where: { $0.userID == userID })?.role ?? .member
    }

    func kickMember(_ member: FrequencyMember) async {
        guard currentUserRole.canKick, member.role.canBeKicked, member.userID != userID else { return }
        do {
            try await cloudKit.kickMember(member)
            members.removeAll { $0.recordName == member.recordName }
            Log.cloudkit.info("Kicked member: \(member.displayName, privacy: .public)")
        } catch {
            Log.cloudkit.error("Kick error: \(error, privacy: .public)")
        }
    }

    func banMember(_ member: FrequencyMember) async {
        guard currentUserRole.canBan, member.role.canBeKicked, member.userID != userID else { return }
        do {
            try await cloudKit.banUser(userID: member.userID, from: frequency, by: userID)
            members.removeAll { $0.recordName == member.recordName }
            await loadBans()
            Log.cloudkit.info("Banned member: \(member.displayName, privacy: .public)")
        } catch {
            Log.cloudkit.error("Ban error: \(error, privacy: .public)")
        }
    }

    func unbanUser(_ ban: FrequencyBan) async {
        guard currentUserRole.canBan else { return }
        do {
            try await cloudKit.unbanUser(userID: ban.bannedUserID, from: frequency)
            bans.removeAll { $0.id == ban.id }
            Log.cloudkit.info("Unbanned user: \(ban.bannedUserID, privacy: .public)")
        } catch {
            Log.cloudkit.error("Unban error: \(error, privacy: .public)")
        }
    }

    func promoteMember(_ member: FrequencyMember) async {
        guard currentUserRole.canPromote, member.role == .member else { return }
        do {
            try await cloudKit.setMemberRole(member, role: .moderator)
            await loadMembers()
            Log.cloudkit.info("Promoted: \(member.displayName, privacy: .public)")
        } catch {
            Log.cloudkit.error("Promote error: \(error, privacy: .public)")
        }
    }

    func demoteMember(_ member: FrequencyMember) async {
        guard currentUserRole.canPromote, member.role == .moderator else { return }
        do {
            try await cloudKit.setMemberRole(member, role: .member)
            await loadMembers()
            Log.cloudkit.info("Demoted: \(member.displayName, privacy: .public)")
        } catch {
            Log.cloudkit.error("Demote error: \(error, privacy: .public)")
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
            Log.cloudkit.info("Voice message sent: \(msg.id, privacy: .public), duration: \(duration, privacy: .public)s")
        } catch {
            Log.cloudkit.error("Send voice message error: \(error, privacy: .public)")
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
