import Foundation
import CloudKit

struct FrequencyBan: Identifiable, Sendable {
    static let recordType = "FrequencyBan"

    let recordName: String
    let frequencyRef: CKRecord.Reference
    let bannedUserID: String
    let bannedBy: String
    let bannedAt: Date

    var id: String { recordName }
    var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    init(
        recordName: String = UUID().uuidString,
        frequencyRef: CKRecord.Reference,
        bannedUserID: String,
        bannedBy: String,
        bannedAt: Date = .now
    ) {
        self.recordName = recordName
        self.frequencyRef = frequencyRef
        self.bannedUserID = bannedUserID
        self.bannedBy = bannedBy
        self.bannedAt = bannedAt
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let frequencyRef = record["frequencyRef"] as? CKRecord.Reference,
              let bannedUserID = record["bannedUserID"] as? String,
              let bannedBy = record["bannedBy"] as? String,
              let bannedAt = record["bannedAt"] as? Date
        else { return nil }

        self.recordName = record.recordID.recordName
        self.frequencyRef = frequencyRef
        self.bannedUserID = bannedUserID
        self.bannedBy = bannedBy
        self.bannedAt = bannedAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: ckRecordID)
        record["frequencyRef"] = frequencyRef
        record["bannedUserID"] = bannedUserID
        record["bannedBy"] = bannedBy
        record["bannedAt"] = bannedAt
        return record
    }
}
