import Foundation
import CloudKit

struct VoiceMessage: Identifiable, Sendable {
    static let recordType = "VoiceMessage"

    let recordName: String
    let frequencyRef: CKRecord.Reference

    var id: String { recordName }
    var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }
    let senderID: String
    let senderName: String
    let audioAssetURL: URL?
    let duration: TimeInterval
    let createdAt: Date
    let expiresAt: Date

    var isExpired: Bool { Date.now >= expiresAt }
    var timeRemaining: TimeInterval { max(0, expiresAt.timeIntervalSinceNow) }

    init(
        recordName: String = UUID().uuidString,
        frequencyRef: CKRecord.Reference,
        senderID: String,
        senderName: String,
        audioURL: URL?,
        duration: TimeInterval,
        createdAt: Date = .now
    ) {
        self.recordName = recordName
        self.frequencyRef = frequencyRef
        self.senderID = senderID
        self.senderName = senderName
        self.audioAssetURL = audioURL
        self.duration = duration
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(10 * 60) // 10 minutes
    }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let frequencyRef = record["frequencyRef"] as? CKRecord.Reference,
              let senderID = record["senderID"] as? String,
              let senderName = record["senderName"] as? String,
              let duration = record["duration"] as? Double,
              let createdAt = record["createdAt"] as? Date,
              let expiresAt = record["expiresAt"] as? Date
        else { return nil }

        self.recordName = record.recordID.recordName
        self.frequencyRef = frequencyRef
        self.senderID = senderID
        self.senderName = senderName
        self.duration = duration
        self.createdAt = createdAt
        self.expiresAt = expiresAt

        if let asset = record["audio"] as? CKAsset {
            self.audioAssetURL = asset.fileURL
        } else {
            self.audioAssetURL = nil
        }
    }

    func toRecord(audioFileURL: URL) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: ckRecordID)
        record["frequencyRef"] = frequencyRef
        record["senderID"] = senderID
        record["senderName"] = senderName
        record["audio"] = CKAsset(fileURL: audioFileURL)
        record["duration"] = duration
        record["createdAt"] = createdAt
        record["expiresAt"] = expiresAt
        return record
    }
}
