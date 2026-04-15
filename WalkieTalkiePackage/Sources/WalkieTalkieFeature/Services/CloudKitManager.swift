import CloudKit
import Foundation
import Observation

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
            print("[CloudKit] Account status: \(status.rawValue) for container: \(Self.containerID)")
            switch status {
            case .available:
                isAvailable = true
                statusMessage = nil
                print("[CloudKit] ✅ Available")
            case .noAccount:
                isAvailable = false
                statusMessage = "Active iCloud dans Réglages pour utiliser WalkieTalkie"
                print("[CloudKit] ❌ No iCloud account")
            case .restricted:
                isAvailable = false
                statusMessage = "iCloud est restreint sur cet appareil"
            default:
                isAvailable = false
                statusMessage = "iCloud temporairement indisponible (status: \(status.rawValue))"
            }
        } catch {
            isAvailable = false
            statusMessage = "Erreur iCloud: \(error.localizedDescription)"
            print("[CloudKit] ❌ Error checking availability: \(error)")
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
        print("[CloudKit] 🔍 Searching for frequency with code: \(searchCode)")
        let predicate = NSPredicate(format: "code == %@", searchCode)
        let query = CKQuery(recordType: Frequency.recordType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            let record = try results.first?.1.get()
            if let freq = record.flatMap(Frequency.init(record:)) {
                print("[CloudKit] ✅ Found frequency: \(freq.name)")
                return freq
            }
            print("[CloudKit] ⚠️ No frequency found for code: \(searchCode)")
            return nil
        } catch {
            print("[CloudKit] ❌ Find frequency error: \(error)")
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
        let member = FrequencyMember(
            frequencyRef: CKRecord.Reference(recordID: frequency.ckRecordID, action: .none),
            userID: userID,
            displayName: displayName
        )
        _ = try await publicDB.save(member.toRecord())
    }

    func leaveFrequency(_ frequency: Frequency, userID: String) async throws {
        let predicate = NSPredicate(format: "frequencyRef == %@ AND userID == %@",
                                    CKRecord.Reference(recordID: frequency.ckRecordID, action: .none), userID)
        let query = CKQuery(recordType: FrequencyMember.recordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

        if let recordID = results.first?.0 {
            try await publicDB.deleteRecord(withID: recordID)
        }
    }

    /// Kick a specific member from a frequency (by recordName)
    func kickMember(_ member: FrequencyMember) async throws {
        try await publicDB.deleteRecord(withID: member.ckRecordID)
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
        return results.compactMap { _, result in
            guard let record = try? result.get() else { return nil }
            return FrequencyMember(record: record)
        }
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
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)
        let predicate = NSPredicate(format: "frequencyRef == %@", ref)
        let subscription = CKQuerySubscription(
            recordType: VoiceMessage.recordType,
            predicate: predicate,
            subscriptionID: "messages-\(frequency.recordName)",
            options: [.firesOnRecordCreation]
        )

        let info = CKSubscription.NotificationInfo()
        // User-visible notification on lock screen (even if app is killed)
        info.title = frequency.name
        info.alertBody = "Nouveau vocal"
        info.soundName = "default"
        info.shouldBadge = true
        // Also wake app to update badge/local state
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["senderName"]
        subscription.notificationInfo = info

        _ = try await publicDB.save(subscription)
    }

    func unsubscribeFromMessages(for frequency: Frequency) async throws {
        let subID = "messages-\(frequency.recordName)"
        try await publicDB.deleteSubscription(withID: subID)
    }

    // MARK: - Delete Frequency (creator only)

    func deleteFrequency(_ frequency: Frequency) async throws {
        let ref = CKRecord.Reference(recordID: frequency.ckRecordID, action: .none)

        // Delete all members
        let memberPred = NSPredicate(format: "frequencyRef == %@", ref)
        let memberQuery = CKQuery(recordType: FrequencyMember.recordType, predicate: memberPred)
        let (memberResults, _) = try await publicDB.records(matching: memberQuery)
        for (recordID, _) in memberResults {
            try? await publicDB.deleteRecord(withID: recordID)
        }

        // Delete all voice messages
        let msgPred = NSPredicate(format: "frequencyRef == %@", ref)
        let msgQuery = CKQuery(recordType: VoiceMessage.recordType, predicate: msgPred)
        let (msgResults, _) = try await publicDB.records(matching: msgQuery)
        for (recordID, _) in msgResults {
            try? await publicDB.deleteRecord(withID: recordID)
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
