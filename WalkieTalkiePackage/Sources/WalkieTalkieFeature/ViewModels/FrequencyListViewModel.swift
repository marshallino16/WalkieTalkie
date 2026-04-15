import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class FrequencyListViewModel {
    private(set) var frequencies: [Frequency] = []
    private(set) var memberCounts: [String: Int] = [:] // code → count
    private(set) var unreadCounts: [String: Int] = [:] // code → unread
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
        // Load locally saved frequencies immediately
        frequencies = Self.loadLocal()
    }

    // MARK: - Local Persistence

    private static func loadLocal() -> [Frequency] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([Frequency].self, from: data)) ?? []
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
                        print("[CloudKit] 🗑️ Frequency \(freq.code) was deleted remotely, removing locally")
                    }
                }
                frequencies = remote + localOnly
                saveLocal()
                print("[CloudKit] ✅ Loaded \(remote.count) remote + \(localOnly.count) local frequencies")
            } catch {
                // NOT_FOUND is expected when record types don't exist yet (first use)
                let ckError = error as? CKError
                if ckError?.code == .unknownItem {
                    print("[CloudKit] ℹ️ No record types yet (first use), using local data only")
                } else {
                    print("[CloudKit] ❌ Load frequencies error: \(error)")
                    self.error = "Impossible de charger les fréquences"
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
        }

        isLoading = false
    }

    // MARK: - Create

    func createFrequency(name: String, code: String, displayName: String) async -> Frequency? {
        let frequency = Frequency(
            name: name,
            code: code,
            creatorID: userID
        )

        // Save pseudo for future use
        KeychainManager.setDisplayName(displayName)

        // Save to CloudKit
        if cloudKit.isAvailable {
            do {
                let record = frequency.toRecord()
                _ = try await cloudKit.publicDB.save(record)
                print("[CloudKit] ✅ Frequency saved: \(code)")
                try await cloudKit.joinFrequency(frequency, userID: userID, displayName: displayName)
                print("[CloudKit] ✅ Member joined: \(displayName)")
                try? await cloudKit.subscribeToMessages(for: frequency)
            } catch {
                print("[CloudKit] ❌ Create frequency error: \(error)")
            }
        } else {
            print("[CloudKit] ⚠️ Not available. Status: \(cloudKit.statusMessage ?? "unknown")")
        }

        frequencies.insert(frequency, at: 0)
        memberCounts[code] = 1
        saveLocal()
        return frequency
    }

    // MARK: - Join

    func joinFrequency(code: String, displayName: String) async -> Frequency? {
        guard cloudKit.isAvailable else {
            self.error = "iCloud non disponible"
            return nil
        }

        do {
            guard let frequency = try await cloudKit.findFrequency(byCode: code) else {
                self.error = "Fréquence introuvable pour le code \(code.uppercased())"
                return nil
            }
            try await cloudKit.joinFrequency(frequency, userID: userID, displayName: displayName)
            print("[CloudKit] ✅ Joined frequency: \(frequency.name)")
            try? await cloudKit.subscribeToMessages(for: frequency)
            frequencies.insert(frequency, at: 0)
            saveLocal()
            return frequency
        } catch let error as CKError where error.code == .unknownItem {
            self.error = "Index CloudKit manquant. Ajoute un index Queryable sur le champ 'code' du record type 'Frequency' dans le CloudKit Dashboard."
            return nil
        } catch {
            self.error = "Erreur: \(error.localizedDescription)"
            print("[CloudKit] ❌ Join error: \(error)")
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
                print("[CloudKit] ✅ Left frequency: \(frequency.code)")
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
                print("[CloudKit] ✅ Deleted frequency: \(frequency.code)")
            }
        }
    }
}
