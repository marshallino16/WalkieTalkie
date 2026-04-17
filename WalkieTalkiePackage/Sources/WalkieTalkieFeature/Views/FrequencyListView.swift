import SwiftUI

struct FrequencyListView: View {
    @Bindable var viewModel: FrequencyListViewModel
    let onSelect: (Frequency) -> Void

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // CloudKit status banner
                if let msg = viewModel.cloudKit.statusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                        Text(msg)
                            .font(WTTheme.captionFont)
                    }
                    .foregroundStyle(WTTheme.yellow)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(WTTheme.yellow.opacity(0.1))
                    .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                if viewModel.frequencies.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.frequencies) { frequency in
                                Button {
                                    onSelect(frequency)
                                } label: {
                                    FrequencyRow(
                                        frequency: frequency,
                                        memberCount: viewModel.memberCounts[frequency.code] ?? 0,
                                        unreadCount: viewModel.unreadCounts[frequency.code] ?? 0
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable {
                        await viewModel.loadFrequencies()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateFrequencySheet { name, code, displayName in
                Task {
                    if let freq = await viewModel.createFrequency(name: name, code: code, displayName: displayName) {
                        viewModel.showCreateSheet = false
                        onSelect(freq)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showJoinSheet) {
            JoinFrequencySheet(error: viewModel.error) { code, displayName in
                Task {
                    if let freq = await viewModel.joinFrequency(code: code, displayName: displayName) {
                        viewModel.showJoinSheet = false
                        onSelect(freq)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await viewModel.loadFrequencies()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("list.title"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(WTTheme.yellow)

                Text(L10n.string("list.subtitle"))
                    .font(WTTheme.captionFont)
                    .foregroundStyle(WTTheme.lightGray)
                    .tracking(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    viewModel.showJoinSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(WTTheme.yellow)
                        .frame(width: 44, height: 44)
                        .background(WTTheme.darkGray)
                        .clipShape(Circle())
                }

                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(WTTheme.yellow)
                        .clipShape(Circle())
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(WTTheme.yellow.opacity(0.3))

            VStack(spacing: 8) {
                Text(L10n.string("list.empty.title"))
                    .font(WTTheme.headlineFont)
                    .foregroundStyle(.white)

                Text(L10n.string("list.empty.subtitle"))
                    .font(WTTheme.captionFont)
                    .foregroundStyle(WTTheme.lightGray)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label(L10n.string("list.create"), systemImage: "plus")
                        .font(WTTheme.bodyFont)
                }
                .buttonStyle(WTYellowButtonStyle())

                Button {
                    viewModel.showJoinSheet = true
                } label: {
                    Label(L10n.string("list.join"), systemImage: "magnifyingglass")
                        .font(WTTheme.bodyFont)
                }
                .buttonStyle(WTOutlineButtonStyle())
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
