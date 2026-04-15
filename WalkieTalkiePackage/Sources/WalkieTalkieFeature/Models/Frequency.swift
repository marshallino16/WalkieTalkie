import Foundation
import CloudKit

struct Frequency: Identifiable, Hashable, Sendable, Codable {
    static func == (lhs: Frequency, rhs: Frequency) -> Bool { lhs.code == rhs.code }
    func hash(into hasher: inout Hasher) { hasher.combine(code) }

    static let recordType = "Frequency"

    let recordName: String // CKRecord.ID.recordName for CloudKit roundtrip
    let name: String
    let code: String
    let creatorID: String
    let createdAt: Date

    var id: String { code }

    init(recordName: String = UUID().uuidString, name: String, code: String, creatorID: String, createdAt: Date = .now) {
        self.recordName = recordName
        self.name = name
        self.code = code
        self.creatorID = creatorID
        self.createdAt = createdAt
    }

    var ckRecordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let name = record["name"] as? String,
              let code = record["code"] as? String,
              let creatorID = record["creatorID"] as? String,
              let createdAt = record["createdAt"] as? Date
        else { return nil }

        self.recordName = record.recordID.recordName
        self.name = name
        self.code = code
        self.creatorID = creatorID
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: ckRecordID)
        record["name"] = name
        record["code"] = code
        record["creatorID"] = creatorID
        record["createdAt"] = createdAt
        return record
    }

    /// Generate a random frequency code like "XKCD-4782"
    static func generateCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let prefix = String((0..<4).map { _ in letters.randomElement()! })
        let suffix = String(format: "%04d", Int.random(in: 1000...9999))
        return "\(prefix)-\(suffix)"
    }

    /// Deep link URL for sharing
    var shareURL: URL {
        URL(string: "walkietalkie://join/\(code)")!
    }

    /// Share text with deep link
    var shareText: String {
        "Rejoins ma fréquence \"\(name)\" sur WalkieTalkie !\n\(shareURL.absoluteString)\n\nCode : \(code)"
    }

    /// Generate a fake radio frequency number for display
    var displayFrequency: String {
        let hash = abs(code.hashValue)
        let major = 400 + (hash % 100)
        let minor = (hash / 100) % 1000
        return String(format: "%d.%03d", major, minor)
    }
}
