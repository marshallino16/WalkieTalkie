import Testing
import CloudKit
@testable import WalkieTalkieFeature

@Suite("FrequencyBan")
struct FrequencyBanTests {
    @Test("toRecord sets all fields")
    func toRecord() {
        let ref = CKRecord.Reference(recordID: CKRecord.ID(recordName: "freq1"), action: .none)
        let ban = FrequencyBan(
            frequencyRef: ref,
            bannedUserID: "user123",
            bannedBy: "admin456"
        )
        let record = ban.toRecord()
        #expect(record.recordType == FrequencyBan.recordType)
        #expect(record["bannedUserID"] as? String == "user123")
        #expect(record["bannedBy"] as? String == "admin456")
        #expect(record["frequencyRef"] as? CKRecord.Reference == ref)
        #expect(record["bannedAt"] != nil)
    }

    @Test("init from record parses all fields")
    func fromRecord() {
        let ref = CKRecord.Reference(recordID: CKRecord.ID(recordName: "freq1"), action: .none)
        let record = CKRecord(recordType: FrequencyBan.recordType)
        record["frequencyRef"] = ref
        record["bannedUserID"] = "user123"
        record["bannedBy"] = "admin456"
        record["bannedAt"] = Date.now

        let ban = FrequencyBan(record: record)
        #expect(ban != nil)
        #expect(ban?.bannedUserID == "user123")
        #expect(ban?.bannedBy == "admin456")
    }

    @Test("init from record with missing fields returns nil")
    func fromRecordMissing() {
        let record = CKRecord(recordType: FrequencyBan.recordType)
        record["bannedUserID"] = "user123"
        let ban = FrequencyBan(record: record)
        #expect(ban == nil)
    }
}
