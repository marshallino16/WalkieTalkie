import CloudKit
import Foundation
import Observation

enum CloudKitError: LocalizedError, Equatable {
    case userBanned
    case displayNameTaken

    var errorDescription: String? {
        switch self {
        case .userBanned: return L10n.string("error.banned")
        case .displayNameTaken: return L10n.string("error.pseudoTaken")
        }
    }
}

@MainActor
@Observable
final class CloudKitManager {
    static let containerID = "iCloud.com.marshalino.walkietalkie"

    private let container: CKContainer
    let publicDB: CKDatabase

    private(set) var isAvailable = false
    private(set) var statusMessage: String?

    init() {
        self.container = CKContainer(identifier: Self.containerID)
        self.publicDB = container.publicCloudDatabase
    }

    // MARK: - Availability

    func checkAvailability() async {
        do {
            let status = try await container.accountStatus()
            Log.cloudkit.info("Account status: \(status.rawValue, privacy: .public) for container: \(Self.containerID, privacy: .public)")
            switch status {
            case .available:
                isAvailable = true
                statusMessage = nil
                Log.cloudkit.info("Available")
            case .noAccount:
                isAvailable = false
                statusMessage = L10n.string("error.icloudRequired")
                Log.cloudkit.error("No iCloud account")
            case .restricted:
                isAvailable = false
                statusMessage = L10n.string("error.icloudRestricted")
            default:
                isAvailable = false
                statusMessage = L10n.string("error.icloudUnavailable")
            }
        } catch {
            isAvailable = false
            statusMessage = L10n.string("error.icloudError", error.localizedDescription)
            Log.cloudkit.error("Error checking availability: \(error, privacy: .public)")
        }
    }

    // MARK: - Frequency Operations

    func createFrequency(name: String, creatorID: String) async throws -> Frequency {
        let frequency = Frequency(
            name: name,
            code: Frequency.generateCode(),
            creatorID: creatorID
        )
        let record = frequency.toRecord()
        let saved = try await publicDB.save(record)
        return Frequency(record: saved)!
    }

    func findFrequency(byCode code: String) async throws -> Frequency? {
        let searchCode = code.uppercased()
        Log.cloudkit.debug("Searching for frequency with code: \(searchCode, privacy: .public)")
        let predicate = NSPredicate(format: "code == %@", searchCode)
        let query = CKQuery(recordType: Frequency.recordType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            let record = try results.first?.1.get()
            if let freq = record.flatMap(Frequency.init(record:)) {
                Log.cloudkit.info("Found frequency: \(freq.name, privacy: .public)")
                return freq
            }
            Log.cloudkit.warning("No frequency found for code: \(searchCode, privacy: .public)")
            return nil
        } catch {
            Log.cloudkit.error("Find frequency error: \(error, privacy: .public)")
            throw error
        }
    }

    func fetchFrequencies(for userID: String) async throws -> [Frequency] {
        // First get member records for this user
        let memberPredicate = NSPredicate(format: "userID == %@", userID)
        let memberQuery = CKQuery(recordType: FrequencyMember.recordType, predicate: memberPredicate)
        let (memberResults, _) = try await publicDB.records(matching: memberQuery)

        let refs: [CKRecord.Reference] = memberResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return record["frequencyRef"] as? CKRecord.Reference
        }

        guard !refs.isEmpty else { return [] }

        // Fetch the actual frequency records
        let recordIDs = refs.map(\.recordID)
        let fetchResults = try await publicDB.records(for: recordIDs)
        return fetchResults.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return Frequency(record: record)
        }
    }

    // MARK: - Member Operations

    func joinFrequency(_ frequency: Frequency, userID: String, displayName: String) async throws {
        // Check if user is banned (graceful: FrequencyBan record type may not exist yet)
        let isBanned = (try? await isUserBanned(userID: userID, from: frequency)) ?? false
        if isBanned {
            throw CloudKitError.userBanned
        }

        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)

        // Check if user is already a member — update displayName instead of creating a duplicate
        let memberPredicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@", ref, userID)
        let memberQuery = CKQuery(recordType: FrequencyMember.recordType, predicate: memberPredicate)
        let (existing, _) = try await publicDB.records(matching: memberQuery, resultsLimit: 1)

        if let (_, result) = existing.first, let record = try? result.get() {
            // Already a member — just update displayName if it changed
            let oldName = record["displayName"] as? String ?? ""
            if oldName != displayName {
                // Verify the new name isn't taken by someone else
                if try await isDisplayNameTaken(displayName, in: frequency, excludingUserID: userID) {
                    throw CloudKitError.displayNameTaken
                }
                record["displayName"] = displayName
                _ = try await publicDB.save(record)
            }
            return
        }

        // New member — check displayName availability
        if try await isDisplayNameTaken(displayName, in: frequency, excludingUserID: userID) {
            throw CloudKitError.displayNameTaken
        }

        let member = FrequencyMember(
            frequencyRef: ref,
            userID: userID,
            displayName: displayName
        )
        _ = try await publicDB.save(member.toRecord())
    }

    /// Check if a displayName is already used in a frequency by another user
    func isDisplayNameTaken(_ displayName: String, in frequency: Frequency, excludingUserID userID: String) async throws -> Bool {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@ AND displayName ==[c] %@", ref, displayName)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 5)
        // Check if any of the results belong to a different user
        return results.contains { _, result in
            guard let record = try? result.get() else { return false }
            return (record["userID"] as? String) != userID
        }
    }

    func leaveFrequency(_ frequency: Frequency, userID: String) async throws {
        let predicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@",
                                    CKRecord.Reference(recordID: frequency.ckRecordID, action: .none), userID)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        // Delete ALL records for this user (handles duplicates)
        let (results, _) = try await publicDB.records(matching: query)
        for (recordID, _) in results {
            try? await publicDB.deleteRecord(withID: recordID)
        }
    }

    /// Check if a specific user is a member of a frequency (targeted query, not paginated)
    func isUserMember(userID: String, of frequency: Frequency) async throws -> Bool {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@", ref, userID)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    /// Kick a specific member from a frequency (by recordName)
    func kickMember(_ member: FrequencyMember) async throws {
        try await publicDB.deleteRecord(withID: member.ckRecordID)
    }

    // MARK: - Bans

    func banUser(userID: String, from frequency: Frequency, by moderatorID: String) async throws {
        let ban = FrequencyBan(
            frequencyRef: CKRecord.Reference(recordID: frequency.ckRecordID, action: .none),
            bannedUserID: userID,
            bannedBy: moderatorID
        )
        _ = try await publicDB.save(ban.toRecord())

        // Remove member record
        let predicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@",
                                    CKRecord.Reference(recordID: frequency.ckRecordID, action: .none), userID)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        if let recordID = results.first?.0 {
            try await publicDB.deleteRecord(withID: recordID)
        }
    }

    func unbanUser(userID: String, from frequency: Frequency) async throws {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@ AND bannedUserID == %@", ref, userID)
        let query = CKQuery(recordType: FrequencyBan.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        if let recordID = results.first?.0 {
            try await publicDB.deleteRecord(withID: recordID)
        }
    }

    func fetchBans(for frequency: Frequency) async throws -> [FrequencyBan] {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@", ref)
        let query = CKQuery(recordType: FrequencyBan.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return FrequencyBan(record: record)
        }
    }

    func isUserBanned(userID: String, from frequency: Frequency) async throws -> Bool {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@ AND bannedUserID == %@", ref, userID)
        let query = CKQuery(recordType: FrequencyBan.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    // MARK: - Roles

    func setMemberRole(_ member: FrequencyMember, role: MemberRole) async throws {
        let record = try await publicDB.record(for: member.ckRecordID)
        record["role"] = role.rawValue
        _ = try await publicDB.save(record)
    }

    /// Update current user's speaking timestamp (live indicator)
    func setSpeaking(_ frequency: Frequency, userID: String, until: Date?) async throws {
        let predicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@",
                                    CKRecord.Reference(recordID: frequency.ckRecordID, action: .none), userID)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        guard let (_, result) = results.first,
              let record = try? result.get() else { return }

        if let until {
            record["speakingUntil"] = until
        } else {
            record["speakingUntil"] = nil
        }
        _ = try await publicDB.save(record)
    }

    func fetchMembers(for frequency: Frequency) async throws -> [FrequencyMember] {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@", ref)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        let allMembers = results.compactMap { _, result in
            guard let record = try? result.get() else { return nil as FrequencyMember? }
            return FrequencyMember(record: record)
        }

        // Deduplicate: keep the most recent record per userID, delete extras
        var seen: [String: FrequencyMember] = [:]
        var duplicateIDs: [CKRecord.ID] = []
        for member in allMembers {
            if let existing = seen[member.userID] {
                // Keep the one with the later joinedAt date
                if member.joinedAt > existing.joinedAt {
                    duplicateIDs.append(existing.ckRecordID)
                    seen[member.userID] = member
                } else {
                    duplicateIDs.append(member.ckRecordID)
                }
            } else {
                seen[member.userID] = member
            }
        }

        // Clean up duplicates in the background
        if !duplicateIDs.isEmpty {
            Log.cloudkit.info("Cleaning \(duplicateIDs.count, privacy: .public) duplicate member records")
            Task.detached { [publicDB] in
                for id in duplicateIDs {
                    try? await publicDB.deleteRecord(withID: id)
                }
            }
        }

        return Array(seen.values).sorted { $0.joinedAt < $1.joinedAt }
    }

    func memberCount(for frequency: Frequency) async throws -> Int {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@", ref)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)
        return results.count
    }

    // MARK: - Voice Message Operations

    func sendVoiceMessage(
        to frequency: Frequency,
        senderID: String,
        senderName: String,
        audioURL: URL,
        duration: TimeInterval
    ) async throws -> VoiceMessage {
        let message = VoiceMessage(
            frequencyRef: CKRecord.Reference(recordID: frequency.ckRecordID, action: .none),
            senderID: senderID,
            senderName: senderName,
            audioURL: audioURL,
            duration: duration
        )
        let record = message.toRecord(audioFileURL: audioURL)
        let saved = try await publicDB.save(record)
        return VoiceMessage(record: saved)!
    }

    func fetchMessages(for frequency: Frequency) async throws -> [VoiceMessage] {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let now = Date.now
        let predicate = NSPredicate(format: "frequencyRef == %@ AND expiresAt > %@", ref, now as NSDate)
        let query = CKQuery(recordType: VoiceMessage.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return VoiceMessage(record: record)
        }
    }

    func deleteMessage(_ message: VoiceMessage) async throws {
        try await publicDB.deleteRecord(withID: message.ckRecordID)
    }

    // MARK: - Subscriptions

    func subscribeToMessages(for frequency: Frequency) async throws {
        let subID = "messages-\(frequency.recordName)"

        // Delete existing subscription first — save() fails on duplicate IDs
        try? await publicDB.deleteSubscription(withID: subID)

        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@", ref)
        let subscription = CKQuerySubscription(
            recordType: VoiceMessage.recordType,
            predicate: predicate,
            subscriptionID: subID,
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        info.title = frequency.name
        info.alertLocalizationKey = "VOICE_MESSAGE_BODY"
        info.alertLocalizationArgs = ["senderName"]
        info.soundName = "default"
        info.shouldBadge = true
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["senderName"]
        subscription.notificationInfo = info

        _ = try await publicDB.save(subscription)
    }

    func unsubscribeFromMessages(for frequency: Frequency) async throws {
        let subID = "messages-\(frequency.recordName)"
        try await publicDB.deleteSubscription(withID: subID)
    }

    // MARK: - Public Channels

    func fetchPublicFrequencies() async -> [Frequency] {
        let predicate = NSPredicate(format: "isPublic == %d", 1)
        let query = CKQuery(recordType: Frequency.recordType, predicate: predicate)
        guard let (results, _) = try? await publicDB.records(matching: query) else { return [] }
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Frequency(record: record)
        }
    }

    func searchPublicFrequencies(name: String) async -> [Frequency] {
        let predicate = NSPredicate(format: "isPublic == %d AND name BEGINSWITH[c] %@", 1, name)
        let query = CKQuery(recordType: Frequency.recordType, predicate: predicate)
        guard let (results, _) = try? await publicDB.records(matching: query) else { return [] }
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Frequency(record: record)
        }
    }

    // MARK: - Admin

    /// Fetch the superadmin password from the AdminConfig record in CloudKit
    func fetchAdminPassword() async -> String? {
        let predicate = NSPredicate(format: "key == %@", "password")
        let query = CKQuery(recordType: "AdminConfig", predicate: predicate)
        guard let (results, _) = try? await publicDB.records(matching: query, resultsLimit: 1),
              let (_, result) = results.first,
              let record = try? result.get() else { return nil }
        return record["value"] as? String
    }

    /// Fetch ALL frequencies (public + private) — admin only
    func fetchAllFrequencies() async -> [Frequency] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Frequency.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        guard let (results, _) = try? await publicDB.records(matching: query) else { return [] }
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Frequency(record: record)
        }
    }

    /// Fetch ALL messages for a frequency (including expired, last 24h) — admin only
    func fetchAllMessages(for frequency: Frequency) async throws -> [VoiceMessage] {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)
        let predicate = NSPredicate(format: "frequencyRef == %@ AND createdAt > %@", ref, oneDayAgo as NSDate)
        let query = CKQuery(recordType: VoiceMessage.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return VoiceMessage(record: record)
        }
    }

    // MARK: - Delete Frequency (creator only)

    func deleteFrequency(_ frequency: Frequency) async throws {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)

        // Delete all members
        let memberPred = NSPredicate(format: "frequencyRef == %@", ref)
        let memberQuery = CKQuery(recordType: FrequencyMember.recordType, predicate: memberPred)
        let (memberResults, _) = try await publicDB.records(matching: memberQuery)
        for (recordID, _) in memberResults {
            _ = try? await publicDB.deleteRecord(withID: recordID)
        }

        // Delete all voice messages
        let msgPred = NSPredicate(format: "frequencyRef == %@", ref)
        let msgQuery = CKQuery(recordType: VoiceMessage.recordType, predicate: msgPred)
        let (msgResults, _) = try await publicDB.records(matching: msgQuery)
        for (recordID, _) in msgResults {
            _ = try? await publicDB.deleteRecord(withID: recordID)
        }

        // Delete bans (record type may not exist yet)
        if let (banResults, _) = try? await publicDB.records(
            matching: CKQuery(recordType: FrequencyBan.recordType, predicate: NSPredicate(format: "frequencyRef == %@", ref))
        ) {
            for (recordID, _) in banResults {
                _ = try? await publicDB.deleteRecord(withID: recordID)
            }
        }

        // Delete subscription
        try? await unsubscribeFromMessages(for: frequency)

        // Delete the frequency record itself
        try await publicDB.deleteRecord(withID: frequency.ckRecordID)
    }

    // MARK: - Cleanup expired messages (sender responsibility)

    func cleanupExpiredMessages(senderID: String) async throws {
        let predicate = NSPredicate(format: "senderID == %@ AND expiresAt <= %@",
                                    senderID, Date.now as NSDate)
        let query = CKQuery(recordType: VoiceMessage.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)

        for (recordID, _) in results {
            try await publicDB.deleteRecord(withID: recordID)
        }
    }
}
