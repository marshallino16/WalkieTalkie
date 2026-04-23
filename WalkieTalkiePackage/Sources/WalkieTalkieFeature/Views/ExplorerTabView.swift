import SwiftUI

struct ExplorerTabView: View {
    let cloudKit: CloudKitManager
    let joinedCodes: Set<String>
    let onJoin: (Frequency) -> Void

    @State private var searchText = ""
    @State private var channels: [Frequency] = []
    @State private var memberCounts: [String: Int] = [:]
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 14) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(WTTheme.mediumGray)

                TextField("", text: $searchText, prompt: Text(L10n.string("explorer.search")).foregroundStyle(WTTheme.mediumGray))
                    .font(WTTheme.bodyFont)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(WTTheme.mediumGray)
                    }
                }
            }
            .padding(12)
            .background(WTTheme.darkGray)
            .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
            .padding(.horizontal, 24)

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(WTTheme.yellow)
                Spacer()
            } else if channels.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "radio")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(WTTheme.mediumGray)
                    Text(L10n.string("explorer.empty"))
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(WTTheme.lightGray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(channels) { channel in
                            channelRow(channel)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            await loadChannels()
        }
    }

    private func loadChannels() async {
        isLoading = true
        defer { isLoading = false }

        let fetched: [Frequency]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            fetched = await cloudKit.fetchPublicFrequencies()
        } else {
            fetched = await cloudKit.searchPublicFrequencies(name: searchText.trimmingCharacters(in: .whitespaces))
        }

        var counts: [String: Int] = [:]
        await withTaskGroup(of: (String, Int).self) { group in
            for freq in fetched {
                group.addTask {
                    let count = (try? await self.cloudKit.memberCount(for: freq)) ?? 0
                    return (freq.code, count)
                }
            }
            for await (code, count) in group {
                counts[code] = count
            }
        }
        memberCounts = counts
        channels = fetched.sorted { counts[$0.code, default: 0] > counts[$1.code, default: 0] }
    }

    private func channelRow(_ channel: Frequency) -> some View {
        let alreadyJoined = joinedCodes.contains(channel.code)
        let appearance = FrequencyAppearance.load(for: channel.code)
        let count = memberCounts[channel.code, default: 0]

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.color)
                .frame(width: 40, height: 40)
                .overlay {
                    if appearance.iconName == "default" {
                        Image(systemName: "radio")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                    } else {
                        Image(appearance.iconName, bundle: .main)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name)
                    .font(WTTheme.bodyFont)
                    .foregroundStyle(.white)

                Text(L10n.string("explorer.members", count))
                    .font(WTTheme.monoSmallFont)
                    .foregroundStyle(WTTheme.lightGray)
            }

            Spacer()

            if alreadyJoined {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WTTheme.green)
            } else {
                Button {
                    onJoin(channel)
                } label: {
                    Text(L10n.string("explorer.join"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(WTTheme.yellow)
                        .clipShape(.capsule)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WTTheme.darkGray)
        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
    }
}
