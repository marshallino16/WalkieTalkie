// MemberRole.swift
import Foundation

enum MemberRole: String, Codable, Sendable {
    case creator
    case moderator
    case member

    var canKick: Bool { self == .creator || self == .moderator }
    var canBan: Bool { self == .creator || self == .moderator }
    var canPromote: Bool { self == .creator }
    var canBeKicked: Bool { self != .creator }

    /// Initialize from an optional CloudKit string, defaulting to .member
    init(rawValue: String?) {
        switch rawValue {
        case "creator": self = .creator
        case "moderator": self = .moderator
        default: self = .member
        }
    }
}
