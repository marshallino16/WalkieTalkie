import SwiftUI
import CloudKit
import UserNotifications
import WalkieTalkieFeature

@main
struct WalkieTalkieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register for remote notifications (required for CKQuerySubscription)
        application.registerForRemoteNotifications()
        // Set self as notification delegate to show notifications when app is in foreground
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notification Handling

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Parse the CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              let queryNotification = notification as? CKQueryNotification else {
            completionHandler(.noData)
            return
        }

        // Extract sender name from the record fields if available
        let senderName = queryNotification.recordFields?["senderName"] as? String ?? "Quelqu'un"
        let subscriptionID = queryNotification.subscriptionID ?? ""

        // Create a visible local notification
        let content = UNMutableNotificationContent()
        content.title = "Nouveau message vocal"
        content.body = "\(senderName) a envoyé un vocal"
        content.sound = .default
        content.categoryIdentifier = "VOICE_MESSAGE"

        let request = UNNotificationRequest(
            identifier: subscriptionID + "_" + UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] ❌ Failed to schedule: \(error)")
            } else {
                print("[Notifications] ✅ Local notification scheduled for \(senderName)")
            }
        }

        completionHandler(.newData)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
