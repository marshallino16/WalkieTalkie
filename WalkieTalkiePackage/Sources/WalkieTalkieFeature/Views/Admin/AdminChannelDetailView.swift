import SwiftUI
import AVFoundation

struct AdminChannelDetailView: View {
    let frequency: Frequency
    let cloudKit: CloudKitManager

    @State private var members: [FrequencyMember] = []
    @State private var messages: [VoiceMessage] = []
    @State private var isLoading = false
    @State private var playingMessageID: String?
    @State private var audioPlayer: AVPlayer?
    @State private var showBanConfirm = false
    @State private var memberToBan: FrequencyMember?

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    channelHeader
                        .padding(.bottom, 16)

                    sectionHeader(L10n.string("admin.detail.members", members.count))
                    ForEach(members) { member in
                        memberRow(member)
                    }

                    sectionHeader(L10n.string("admin.detail.messages", messages.count))
                        .padding(.top, 20)
                    if messages.isEmpty {
                        Text(L10n.string("admin.detail.noMessages"))
                            .font(WTTheme.captionFont)
                            .foregroundStyle(WTTheme.lightGray)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(messages) { msg in
                            audioRow(msg)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable { await loadAll() }
        }
        .navigationTitle(frequency.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadAll() }
        .onDisappear { stopAudio() }
        .alert(L10n.string("admin.ban.title"), isPresented: $showBanConfirm) {
            Button(L10n.string("channel.cancel"), role: .cancel) {}
            Button(L10n.string("admin.ban.confirm"), role: .destructive) {
                if let member = memberToBan {
                    Task { await banMember(member) }
                }
            }
        } message: {
            if let member = memberToBan {
                Text(L10n.string("admin.ban.message", member.displayName))
            }
        }
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: frequency.isPublic ? "globe" : "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(frequency.isPublic ? WTTheme.green : WTTheme.lightGray)
                        Text(frequency.isPublic ? L10n.string("admin.detail.public") : L10n.string("admin.detail.private"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(WTTheme.lightGray)
                    }
                    Text(frequency.code)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(WTTheme.yellow)
                }
                Spacer()
                Text(frequency.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WTTheme.mediumGray)
            }
            .padding(12)
            .background(WTTheme.darkGray)
            .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(WTTheme.lightGray)
                .tracking(1.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Member Row

    private func memberRow(_ member: FrequencyMember) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(roleColor(member.role))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                    if member.role != .member {
                        Text(member.role.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor(member.role))
                            .clipShape(.capsule)
                    }
                }
                Text(member.userID.prefix(8) + "...")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(WTTheme.mediumGray)
            }

            Spacer()

            if member.role != .creator {
                Button {
                    memberToBan = member
                    showBanConfirm = true
                } label: {
                    Image(systemName: "hand.raised.slash.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(WTTheme.red)
                        .padding(8)
                        .background(WTTheme.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WTTheme.darkGray.opacity(0.5))
        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
        .padding(.bottom, 4)
    }

    private func roleColor(_ role: MemberRole) -> Color {
        switch role {
        case .creator: WTTheme.yellow
        case .moderator: .orange
        case .member: WTTheme.green
        }
    }

    // MARK: - Audio Row (spy mode — no side effects)

    private func audioRow(_ msg: VoiceMessage) -> some View {
        let isPlaying = playingMessageID == msg.id
        let isExpired = msg.isExpired

        return HStack(spacing: 10) {
            Button {
                if isPlaying {
                    stopAudio()
                } else {
                    playAudio(msg)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isPlaying ? WTTheme.red : WTTheme.yellow)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(msg.senderName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(String(format: "%.0fs", msg.duration))
                        .foregroundStyle(WTTheme.lightGray)
                    Text(msg.createdAt.formatted(date: .omitted, time: .standard))
                        .foregroundStyle(WTTheme.mediumGray)
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            }

            Spacer()

            if isExpired {
                Text(L10n.string("admin.detail.expired"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WTTheme.red.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WTTheme.red.opacity(0.1))
                    .clipShape(.capsule)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WTTheme.darkGray.opacity(0.5))
        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
        .padding(.bottom, 4)
    }

    // MARK: - Audio Playback (no side effects)

    private func playAudio(_ message: VoiceMessage) {
        guard let url = message.audioAssetURL else { return }
        stopAudio()
        let player = AVPlayer(url: url)
        self.audioPlayer = player
        playingMessageID = message.id

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor [self] in
                self.playingMessageID = nil
            }
        }
        player.play()
    }

    private func stopAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        playingMessageID = nil
    }

    // MARK: - Actions

    private func banMember(_ member: FrequencyMember) async {
        do {
            try await cloudKit.banUser(userID: member.userID, from: frequency, by: "admin")
            members.removeAll { $0.recordName == member.recordName }
        } catch {
            Log.cloudkit.error("Admin ban error: \(error, privacy: .public)")
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        async let fetchedMembers = (try? cloudKit.fetchMembers(for: frequency)) ?? []
        async let fetchedMessages = (try? cloudKit.fetchAllMessages(for: frequency)) ?? []

        members = await fetchedMembers
        messages = await fetchedMessages
    }
}
