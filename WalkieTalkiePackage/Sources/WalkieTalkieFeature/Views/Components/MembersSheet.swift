import SwiftUI

struct MembersSheet: View {
    let members: [FrequencyMember]
    let bans: [FrequencyBan]
    let frequencyName: String
    let currentUserID: String
    let currentUserRole: MemberRole
    let onKick: (FrequencyMember) -> Void
    let onBan: (FrequencyMember) -> Void
    let onUnban: (FrequencyBan) -> Void
    let onPromote: (FrequencyMember) -> Void
    let onDemote: (FrequencyMember) -> Void

    @State private var memberToKick: FrequencyMember?
    @State private var memberToBan: FrequencyMember?
    @State private var memberToPromote: FrequencyMember?

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Handle
                Capsule()
                    .fill(WTTheme.mediumGray)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Title
                VStack(spacing: 6) {
                    Text(L10n.string("members.title"))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(WTTheme.yellow)
                        .tracking(2)

                    Text(frequencyName)
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                }

                if members.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(WTTheme.mediumGray)
                        Text(L10n.string("members.empty"))
                            .font(WTTheme.bodyFont)
                            .foregroundStyle(WTTheme.lightGray)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(members) { member in
                            memberRow(member)
                                .listRowBackground(WTTheme.darkGray)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if currentUserRole.canKick && member.role.canBeKicked && member.userID != currentUserID {
                                        Button {
                                            memberToKick = member
                                        } label: {
                                            Label(L10n.string("members.kick"), systemImage: "person.slash.fill")
                                        }
                                        .tint(.orange)

                                        Button {
                                            memberToBan = member
                                        } label: {
                                            Label(L10n.string("members.ban"), systemImage: "nosign")
                                        }
                                        .tint(.red)
                                    }

                                    if currentUserRole.canPromote && member.role == .member && member.userID != currentUserID {
                                        Button {
                                            memberToPromote = member
                                        } label: {
                                            Label(L10n.string("members.promote"), systemImage: "star.fill")
                                        }
                                        .tint(.blue)
                                    }

                                    if currentUserRole.canPromote && member.role == .moderator {
                                        Button {
                                            onDemote(member)
                                        } label: {
                                            Label(L10n.string("members.demote"), systemImage: "star.slash.fill")
                                        }
                                        .tint(.gray)
                                    }
                                }
                        }

                        // Banned section
                        if currentUserRole.canBan && !bans.isEmpty {
                            Section {
                                ForEach(bans) { ban in
                                    bannedRow(ban)
                                        .listRowBackground(WTTheme.darkGray)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                            } header: {
                                Text(L10n.string("members.banned.title"))
                                    .font(WTTheme.captionFont)
                                    .foregroundStyle(WTTheme.yellow)
                                    .tracking(1.5)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .alert(L10n.string("members.kick.title"), isPresented: Binding(
            get: { memberToKick != nil },
            set: { if !$0 { memberToKick = nil } }
        )) {
            Button(L10n.string("channel.cancel"), role: .cancel) { memberToKick = nil }
            Button(L10n.string("members.kick.button"), role: .destructive) {
                if let member = memberToKick {
                    onKick(member)
                }
                memberToKick = nil
            }
        } message: {
            if let m = memberToKick {
                Text(L10n.string("members.kick.message", m.displayName))
            }
        }
        .alert(L10n.string("members.ban.title"), isPresented: Binding(
            get: { memberToBan != nil },
            set: { if !$0 { memberToBan = nil } }
        )) {
            Button(L10n.string("channel.cancel"), role: .cancel) { memberToBan = nil }
            Button(L10n.string("members.ban.button"), role: .destructive) {
                if let member = memberToBan { onBan(member) }
                memberToBan = nil
            }
        } message: {
            if let m = memberToBan {
                Text(L10n.string("members.ban.message", m.displayName))
            }
        }
        .alert(L10n.string("members.promote.title"), isPresented: Binding(
            get: { memberToPromote != nil },
            set: { if !$0 { memberToPromote = nil } }
        )) {
            Button(L10n.string("channel.cancel"), role: .cancel) { memberToPromote = nil }
            Button(L10n.string("members.promote.button")) {
                if let member = memberToPromote { onPromote(member) }
                memberToPromote = nil
            }
        } message: {
            if let m = memberToPromote {
                Text(L10n.string("members.promote.message", m.displayName))
            }
        }
    }

    private func memberRow(_ member: FrequencyMember) -> some View {
        HStack(spacing: 14) {
            // Avatar with speaking indicator
            ZStack {
                Circle()
                    .fill(WTTheme.yellow)
                    .frame(width: 40, height: 40)

                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)

                if member.isSpeaking {
                    Circle()
                        .strokeBorder(WTTheme.green, lineWidth: 3)
                        .frame(width: 46, height: 46)
                        .opacity(0.8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)

                    if member.userID == currentUserID {
                        Text(L10n.string("members.you"))
                            .font(WTTheme.captionFont)
                            .foregroundStyle(WTTheme.lightGray)
                    }

                    if member.role == .creator {
                        Text(L10n.string("members.role.creator"))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WTTheme.yellow)
                            .clipShape(.capsule)
                    }

                    if member.role == .moderator {
                        Text(L10n.string("members.role.mod"))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(.capsule)
                    }
                }

                if member.isSpeaking {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                            .symbolEffect(.variableColor.iterative, isActive: true)
                        Text(L10n.string("members.speaking"))
                    }
                    .font(WTTheme.monoSmallFont)
                    .foregroundStyle(WTTheme.green)
                } else {
                    Text("Rejoint \(member.joinedAt.formatted(.relative(presentation: .named)))")
                        .font(WTTheme.monoSmallFont)
                        .foregroundStyle(WTTheme.lightGray)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func bannedRow(_ ban: FrequencyBan) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(WTTheme.red.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "nosign")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WTTheme.red)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(ban.bannedUserID)
                    .font(WTTheme.bodyFont)
                    .foregroundStyle(.white.opacity(0.6))

                Text("Banni \(ban.bannedAt.formatted(.relative(presentation: .named)))")
                    .font(WTTheme.monoSmallFont)
                    .foregroundStyle(WTTheme.lightGray)
            }

            Spacer()

            Button {
                onUnban(ban)
            } label: {
                Text(L10n.string("members.unban"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WTTheme.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WTTheme.green.opacity(0.15))
                    .clipShape(.capsule)
            }
        }
        .padding(.vertical, 4)
    }
}
