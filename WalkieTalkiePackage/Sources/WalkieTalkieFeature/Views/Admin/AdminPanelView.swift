import SwiftUI

struct AdminPanelView: View {
    let cloudKit: CloudKitManager

    @State private var frequencies: [Frequency] = []
    @State private var memberCounts: [String: Int] = [:]
    @State private var messageCounts: [String: Int] = [:]
    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    @State private var frequencyToDelete: Frequency?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WTTheme.black.ignoresSafeArea()

                if isLoading && frequencies.isEmpty {
                    ProgressView().tint(WTTheme.yellow)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            statsHeader
                            ForEach(frequencies) { freq in
                                adminChannelRow(freq)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle(L10n.string("admin.panel.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationDestination(for: Frequency.self) { freq in
                AdminChannelDetailView(frequency: freq, cloudKit: cloudKit)
            }
            .task { await loadAll() }
            .alert(L10n.string("admin.delete.title"), isPresented: $showDeleteConfirm) {
                Button(L10n.string("channel.cancel"), role: .cancel) {}
                Button(L10n.string("admin.delete.confirm"), role: .destructive) {
                    if let freq = frequencyToDelete {
                        Task {
                            try? await cloudKit.deleteFrequency(freq)
                            frequencies.removeAll { $0.code == freq.code }
                        }
                    }
                }
            } message: {
                if let freq = frequencyToDelete {
                    Text(L10n.string("admin.delete.message", freq.name))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Stats

    private var statsHeader: some View {
        HStack(spacing: 16) {
            statBox(L10n.string("admin.stats.channels"), value: "\(frequencies.count)")
            statBox(L10n.string("admin.stats.members"), value: "\(memberCounts.values.reduce(0, +))")
            statBox(L10n.string("admin.stats.messages"), value: "\(messageCounts.values.reduce(0, +))")
        }
        .padding(.vertical, 12)
    }

    private func statBox(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(WTTheme.yellow)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WTTheme.lightGray)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(WTTheme.darkGray)
        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
    }

    // MARK: - Channel Row

    private func adminChannelRow(_ freq: Frequency) -> some View {
        NavigationLink(value: freq) {
            HStack(spacing: 12) {
                Image(systemName: freq.isPublic ? "globe" : "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(freq.isPublic ? WTTheme.green : WTTheme.lightGray)
                    .frame(width: 32, height: 32)
                    .background(WTTheme.darkGray)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(freq.name)
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                    HStack(spacing: 12) {
                        Label("\(memberCounts[freq.code, default: 0])", systemImage: "person.2.fill")
                        Label("\(messageCounts[freq.code, default: 0])", systemImage: "waveform")
                        Text(freq.code)
                            .foregroundStyle(WTTheme.mediumGray)
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(WTTheme.lightGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WTTheme.mediumGray)
            }
            .padding(12)
            .background(WTTheme.darkGray.opacity(0.5))
            .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                frequencyToDelete = freq
                showDeleteConfirm = true
            } label: {
                Label(L10n.string("admin.delete.action"), systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        frequencies = await cloudKit.fetchAllFrequencies()

        await withTaskGroup(of: (String, Int, Int).self) { group in
            for freq in frequencies {
                group.addTask {
                    let members = (try? await self.cloudKit.memberCount(for: freq)) ?? 0
                    let messages = (try? await self.cloudKit.fetchAllMessages(for: freq))?.count ?? 0
                    return (freq.code, members, messages)
                }
            }
            for await (code, members, messages) in group {
                memberCounts[code] = members
                messageCounts[code] = messages
            }
        }
    }
}
