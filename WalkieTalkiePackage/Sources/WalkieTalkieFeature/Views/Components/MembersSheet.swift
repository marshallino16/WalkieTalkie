import SwiftUI

struct MembersSheet: View {
    let members: [FrequencyMember]
    let frequencyName: String
    let currentUserID: String
    let isCurrentUserCreator: Bool
    let onKick: (FrequencyMember) -> Void

    @State private var memberToKick: FrequencyMember?

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
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(members) { member in
                                memberRow(member)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
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

            // Kick button (creator only, not self)
            if isCurrentUserCreator && member.userID != currentUserID {
                Button {
                    memberToKick = member
                } label: {
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WTTheme.red)
                        .frame(width: 32, height: 32)
                        .background(WTTheme.red.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(WTTheme.darkGray)
        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
    }
}
