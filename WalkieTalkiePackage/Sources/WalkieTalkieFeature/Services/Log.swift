import os

/// Centralized loggers for the app
enum Log {
    static let cloudkit = Logger(subsystem: "com.genyus.roger.that", category: "CloudKit")
    static let audio = Logger(subsystem: "com.genyus.roger.that", category: "Audio")
    static let notifications = Logger(subsystem: "com.genyus.roger.that", category: "Notifications")
}
