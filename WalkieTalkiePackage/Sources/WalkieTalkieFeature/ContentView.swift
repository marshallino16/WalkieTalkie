import SwiftUI
import UserNotifications

public struct ContentView: View {
    @State private var displayName: String? = KeychainManager.getDisplayName()
    @State private var cloudKit = CloudKitManager()
    @State private var audioEngine = AudioEngineManager()
    @State private var listViewModel: FrequencyListViewModel?
    @State private var navigationPath = NavigationPath()
    @State private var pendingDeepLinkCode: String?

    private var userID: String { KeychainManager.getUserID() }

    public var body: some View {
        Group {
            if let displayName {
                if let listViewModel {
                    mainContent(displayName: displayName, listViewModel: listViewModel)
                }
            } else {
                OnboardingView { pseudo in
                    KeychainManager.setDisplayName(pseudo)
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.displayName = pseudo
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await cloudKit.checkAvailability()
            try? await cloudKit.cleanupExpiredMessages(senderID: userID)
            if listViewModel == nil {
                listViewModel = FrequencyListViewModel(cloudKit: cloudKit, userID: userID)
            }
        }
        .onChange(of: displayName) {
            if displayName != nil, listViewModel == nil {
                listViewModel = FrequencyListViewModel(cloudKit: cloudKit, userID: userID)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    @ViewBuilder
    private func mainContent(displayName: String, listViewModel: FrequencyListViewModel) -> some View {
        NavigationStack(path: $navigationPath) {
            FrequencyListView(
                viewModel: listViewModel,
                onSelect: { frequency in
                    navigationPath.append(frequency)
                    requestNotificationPermission()
                }
            )
            .navigationDestination(for: Frequency.self) { frequency in
                FrequencyDetailView(
                    viewModel: FrequencyDetailViewModel(
                        frequency: frequency,
                        cloudKit: cloudKit,
                        audioEngine: audioEngine,
                        userID: userID,
                        userName: displayName
                    ),
                    appearance: listViewModel.appearances[frequency.code] ?? .default,
                    onLeave: {
                        listViewModel.leaveFrequency(frequency)
                        navigationPath.removeLast()
                    },
                    onDelete: {
                        listViewModel.deleteFrequency(frequency)
                        navigationPath.removeLast()
                    },
                    onKicked: {
                        listViewModel.leaveFrequency(frequency)
                        navigationPath.removeLast()
                    }
                )
            }
        }
        .tint(WTTheme.yellow)
        .onChange(of: pendingDeepLinkCode) {
            guard let code = pendingDeepLinkCode else { return }
            pendingDeepLinkCode = nil
            handleJoinFromDeepLink(code: code, listViewModel: listViewModel)
        }
        .onAppear {
            // Handle deep link that arrived before view was ready
            if let code = pendingDeepLinkCode {
                pendingDeepLinkCode = nil
                handleJoinFromDeepLink(code: code, listViewModel: listViewModel)
            }
        }
    }

    // MARK: - Deep Links

    private func handleDeepLink(_ url: URL) {
        // walkietalkie://join/XKCD-4782
        guard url.scheme == "walkietalkie",
              url.host == "join",
              let code = url.pathComponents.last, code != "/"
        else { return }

        pendingDeepLinkCode = code.uppercased()
    }

    private func handleJoinFromDeepLink(code: String, listViewModel: FrequencyListViewModel) {
        // Check if already in this frequency
        if let existing = listViewModel.frequencies.first(where: { $0.code == code }) {
            navigationPath.append(existing)
            return
        }

        // Auto-join via CloudKit
        Task {
            let name = KeychainManager.getDisplayName() ?? "Anonyme"
            if let freq = await listViewModel.joinFrequency(code: code, displayName: name) {
                navigationPath.append(freq)
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    public init() {}
}
