import Foundation
import CloudKit

struct FrequencyMember: Identifiable, Sendable {
    static let recordType = "FrequencyMember"

    let recordName: String
    let frequencyRef: CKRecord.Reference
    let userID: String
    let joinedAt: Date
    let displayName: String
    let speakingUntil: Date?

    var id: String { recordName }
    var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    /// Member is considered speaking if timestamp is in the future
    var isSpeaking: Bool {
        guard let until = speakingUntil else { return false }
        return until > Date.now
    }

    init(
        recordName: String = UUID().uuidString,
        frequencyRef: CKRecord.Reference,
        userID: String,
        displayName: String,
        joinedAt: Date = .now,
        speakingUntil: Date? = nil
    ) {
        self.recordName = recordName
        self.frequencyRef = frequencyRef
        self.userID = userID
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.speakingUntil = speakingUntil
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let frequencyRef = record["frequencyRef"] as? CKRecord.Reference,
              let userID = record["userID"] as? String,
              let displayName = record["displayName"] as? String,
              let joinedAt = record["joinedAt"] as? Date
        else { return nil }

        self.recordName = record.recordID.recordName
        self.frequencyRef = frequencyRef
        self.userID = userID
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.speakingUntil = record["speakingUntil"] as? Date
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: ckRecordID)
        record["frequencyRef"] = frequencyRef
        record["userID"] = userID
        record["displayName"] = displayName
        record["joinedAt"] = joinedAt
        if let speakingUntil {
            record["speakingUntil"] = speakingUntil
        }
        return record
    }
}
