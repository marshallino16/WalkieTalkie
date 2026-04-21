import Testing
import CloudKit
@testable import WalkieTalkieFeature

@Suite("Frequency isPublic")
struct FrequencyPublicTests {
    @Test("Default is false")
    func defaultPrivate() {
        let freq = Frequency(name: "Test", code: "ABCD-1234", creatorID: "user1")
        #expect(!freq.isPublic)
    }

    @Test("toRecord serializes isPublic as Int64")
    func toRecord() {
        let freq = Frequency(name: "Test", code: "ABCD-1234", creatorID: "user1", isPublic: true)
        let record = freq.toRecord()
        #expect(record["isPublic"] as? Int64 == 1)
    }

    @Test("init from record without isPublic defaults to false")
    func fromRecordMissing() {
        let record = CKRecord(recordType: Frequency.recordType)
        record["name"] = "Test"
        record["code"] = "ABCD-1234"
        record["creatorID"] = "user1"
        record["createdAt"] = Date.now
        let freq = Frequency(record: record)
        #expect(freq != nil)
        #expect(freq?.isPublic == false)
    }

    @Test("init from record parses isPublic = 1 as true")
    func fromRecordTrue() {
        let record = CKRecord(recordType: Frequency.recordType)
        record["name"] = "Test"
        record["code"] = "ABCD-1234"
        record["creatorID"] = "user1"
        record["createdAt"] = Date.now
        record["isPublic"] = 1 as Int64
        let freq = Frequency(record: record)
        #expect(freq?.isPublic == true)
    }
}
