import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class FrequencyListViewModel {
    private(set) var frequencies: [Frequency] = []
    private(set) var memberCounts: [String: Int] = [:] // code → count
    private(set) var unreadCounts: [String: Int] = [:] // code → unread
    var appearances: [String: FrequencyAppearance] = [:] // code → appearance
    private(set) var isLoading = false
    private(set) var error: String?

    var showCreateSheet = false
    var showJoinSheet = false

    let cloudKit: CloudKitManager
    let userID: String

    private static let storageKey = "savedFrequencies"

    init(cloudKit: CloudKitManager, userID: String) {
        self.cloudKit = cloudKit
        self.userID = userID
        frequencies = Self.loadLocal()
        loadAppearances()
    }

    func loadAppearances() {
        for freq in frequencies {
            appearances[freq.code] = FrequencyAppearance.load(for: freq.code)
        }
    }

    func updateAppearance(_ appearance: FrequencyAppearance, for code: String) {
        FrequencyAppearance.save(appearance, for: code)
        appearances[code] = appearance
    }

    // MARK: - Local Persistence

    private static func loadLocal() -> [Frequency] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        let stored = (try? JSONDecoder().decode([Frequency].self, from: data)) ?? []
        return stored.sorted(by: { (a: Frequency, b: Frequency) in a.createdAt > b.createdAt })
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(frequencies) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Loading

    func loadFrequencies() async {
        isLoading = true
        error = nil

        if cloudKit.isAvailable {
            do {
                let remote = try await cloudKit.fetchFrequencies(for: userID)
                // Verify local-only frequencies still exist on CloudKit
                let remoteCodes = Set(remote.map(\.code))
                var localOnly: [Frequency] = []
                for freq in frequencies where !remoteCodes.contains(freq.code) {
                    // Check if this frequency still exists (creator might have deleted it)
                    if let _ = try? await cloudKit.findFrequency(byCode: freq.code) {
                        localOnly.append(freq)
                    } else {
                        Log.cloudkit.info("Frequency \(freq.code, privacy: .public) was deleted remotely, removing locally")
                    }
                }
                // Sort: most recently created first (stable order across refreshes)
                frequencies = (remote + localOnly).sorted(by: { (a: Frequency, b: Frequency) in
                    a.createdAt > b.createdAt
                })
                saveLocal()
                Log.cloudkit.info("Loaded \(remote.count, privacy: .public) remote + \(localOnly.count, privacy: .public) local frequencies")
            } catch {
                // NOT_FOUND is expected when record types don't exist yet (first use)
                let ckError = error as? CKError
                if ckError?.code == .unknownItem {
                    Log.cloudkit.info("No record types yet (first use), using local data only")
                } else {
                    Log.cloudkit.error("Load frequencies error: \(error, privacy: .public)")
                    self.error = L10n.string("error.loadFailed")
                }
            }

            // Fetch member counts and unread counts in parallel
            let snapshotUserID = userID
            await withTaskGroup(of: (String, Int, Int).self) { group in
                for freq in frequencies {
                    group.addTask {
                        async let memberCount = (try? await self.cloudKit.memberCount(for: freq)) ?? 0
                        async let messages = (try? await self.cloudKit.fetchMessages(for: freq)) ?? []

                        let listenedKey = "listened_\(freq.code)"
                        let listened = Set(UserDefaults.standard.stringArray(forKey: listenedKey) ?? [])
                        let allMessages = await messages
                        let unread = allMessages.filter { msg in
                            !msg.isExpired && msg.senderID != snapshotUserID && !listened.contains(msg.id)
                        }.count

                        return (freq.code, await memberCount, unread)
                    }
                }
                for await (code, memberCount, unread) in group {
                    memberCounts[code] = memberCount
                    unreadCounts[code] = unread
                }
            }

            // Refresh subscriptions (fire-and-forget) to apply latest notification config
            for freq in frequencies {
                Task.detached { [cloudKit] in
                    try? await cloudKit.subscribeToMessages(for: freq)
                }
            }
        }

        isLoading = false
    }

    // MARK: - Create

    func createFrequency(name: String, code: String, displayName: String, isPublic: Bool = false) async -> Frequency? {
        let frequency = Frequency(
            name: name,
            code: code,
            creatorID: userID,
            isPublic: isPublic
        )

        // Save pseudo for future use
        KeychainManager.setDisplayName(displayName)

        // Save to CloudKit
        if cloudKit.isAvailable {
            do {
                let record = frequency.toRecord()
                _ = try await cloudKit.publicDB.save(record)
                Log.cloudkit.info("Frequency saved: \(code, privacy: .public)")
                try await cloudKit.joinFrequency(frequency, userID: userID, displayName: displayName)
                Log.cloudkit.info("Creator joined: \(displayName, privacy: .public)")
                // Best-effort: upgrade role to creator
                let members = try? await cloudKit.fetchMembers(for: frequency)
                if let myMember = members?.first(where: { $0.userID == userID }) {
                    try? await cloudKit.setMemberRole(myMember, role: .creator)
                }
                try? await cloudKit.subscribeToMessages(for: frequency)
            } catch {
                Log.cloudkit.error("Create frequency error: \(error, privacy: .public)")
            }
        } else {
            let status = self.cloudKit.statusMessage ?? "unknown"
            Log.cloudkit.warning("Not available. Status: \(status, privacy: .public)")
        }

        frequencies.insert(frequency, at: 0)
        memberCounts[code] = 1
        saveLocal()
        return frequency
    }

    // MARK: - Join

    func clearError() {
        error = nil
    }

    func joinFrequency(code: String, displayName: String) async -> Frequency? {
        error = nil
        guard cloudKit.isAvailable else {
            self.error = L10n.string("error.icloudNotAvailable")
            return nil
        }

        do {
            guard let frequency = try await cloudKit.findFrequency(byCode: code) else {
                self.error = L10n.string("error.frequencyNotFound", code.uppercased())
                return nil
            }
            try await cloudKit.joinFrequency(frequency, userID: userID, displayName: displayName)
            Log.cloudkit.info("Joined frequency: \(frequency.name, privacy: .public)")
            try? await cloudKit.subscribeToMessages(for: frequency)
            frequencies.insert(frequency, at: 0)
            saveLocal()
            return frequency
        } catch let error as CloudKitError where error == .displayNameTaken {
            self.error = L10n.string("error.pseudoTaken")
            return nil
        } catch let error as CKError where error.code == .unknownItem {
            self.error = L10n.string("error.indexMissing")
            return nil
        } catch {
            self.error = L10n.string("error.joinFailed", error.localizedDescription)
            Log.cloudkit.error("Join error: \(error, privacy: .public)")
            return nil
        }
    }

    func joinPublicFrequency(_ frequency: Frequency, displayName: String) async -> Frequency? {
        guard cloudKit.isAvailable else {
            self.error = L10n.string("error.icloudNotAvailable")
            return nil
        }

        guard !frequencies.contains(where: { $0.code == frequency.code }) else {
            self.error = L10n.string("error.alreadyJoined")
            return nil
        }

        do {
            try await cloudKit.joinFrequency(frequency, userID: userID, displayName: displayName)
            Log.cloudkit.info("Joined public frequency: \(frequency.name, privacy: .public)")
            try? await cloudKit.subscribeToMessages(for: frequency)
            frequencies.insert(frequency, at: 0)
            saveLocal()
            return frequency
        } catch let error as CloudKitError where error == .userBanned {
            self.error = L10n.string("error.banned")
            return nil
        } catch let error as CloudKitError where error == .displayNameTaken {
            self.error = L10n.string("error.pseudoTaken")
            return nil
        } catch {
            self.error = L10n.string("error.joinFailed", error.localizedDescription)
            Log.cloudkit.error("Join public error: \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Leave

    func leaveFrequency(_ frequency: Frequency) {
        frequencies.removeAll { $0.code == frequency.code }
        memberCounts.removeValue(forKey: frequency.code)
        saveLocal()

        if cloudKit.isAvailable {
            Task {
                try? await cloudKit.leaveFrequency(frequency, userID: userID)
                try? await cloudKit.unsubscribeFromMessages(for: frequency)
                Log.cloudkit.info("Left frequency: \(frequency.code, privacy: .public)")
            }
        }
    }

    // MARK: - Delete (creator only)

    func deleteFrequency(_ frequency: Frequency) {
        frequencies.removeAll { $0.code == frequency.code }
        memberCounts.removeValue(forKey: frequency.code)
        saveLocal()

        if cloudKit.isAvailable {
            Task {
                try? await cloudKit.deleteFrequency(frequency)
                Log.cloudkit.info("Deleted frequency: \(frequency.code, privacy: .public)")
            }
        }
    }
}
