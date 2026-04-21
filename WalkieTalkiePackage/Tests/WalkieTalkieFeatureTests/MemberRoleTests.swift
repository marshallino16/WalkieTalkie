// MemberRoleTests.swift
import Testing
@testable import WalkieTalkieFeature

@Suite("MemberRole")
struct MemberRoleTests {
    @Test("Raw values match CloudKit strings")
    func rawValues() {
        #expect(MemberRole.creator.rawValue == "creator")
        #expect(MemberRole.moderator.rawValue == "moderator")
        #expect(MemberRole.member.rawValue == "member")
    }

    @Test("canKick is true for creator and moderator")
    func canKick() {
        #expect(MemberRole.creator.canKick)
        #expect(MemberRole.moderator.canKick)
        #expect(!MemberRole.member.canKick)
    }

    @Test("canBan is true for creator and moderator")
    func canBan() {
        #expect(MemberRole.creator.canBan)
        #expect(MemberRole.moderator.canBan)
        #expect(!MemberRole.member.canBan)
    }

    @Test("canPromote is true only for creator")
    func canPromote() {
        #expect(MemberRole.creator.canPromote)
        #expect(!MemberRole.moderator.canPromote)
        #expect(!MemberRole.member.canPromote)
    }

    @Test("canBeKicked excludes creator")
    func canBeKicked() {
        #expect(!MemberRole.creator.canBeKicked)
        #expect(MemberRole.moderator.canBeKicked)
        #expect(MemberRole.member.canBeKicked)
    }

    @Test("init from nil defaults to member")
    func initFromNil() {
        let role = MemberRole(rawValue: nil)
        #expect(role == .member)
    }

    @Test("init from unknown string defaults to member")
    func initFromUnknown() {
        let role = MemberRole(rawValue: "admin")
        #expect(role == .member)
    }
}
