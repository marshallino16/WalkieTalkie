import SwiftUI

struct MembersSheet: View {
    let members: [FrequencyMember]
    let frequencyName: String

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
                    Text("MEMBRES")
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
                        Text("Aucun membre pour l'instant")
                            .font(WTTheme.bodyFont)
                            .foregroundStyle(WTTheme.lightGray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(members) { member in
                                HStack(spacing: 14) {
                                    // Avatar circle with initial
                                    ZStack {
                                        Circle()
                                            .fill(WTTheme.yellow)
                                            .frame(width: 40, height: 40)

                                        Text(String(member.displayName.prefix(1)).uppercased())
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.black)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.displayName)
                                            .font(WTTheme.bodyFont)
                                            .foregroundStyle(.white)

                                        Text("Rejoint \(member.joinedAt.formatted(.relative(presentation: .named)))")
                                            .font(WTTheme.monoSmallFont)
                                            .foregroundStyle(WTTheme.lightGray)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(WTTheme.darkGray)
                                .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}
