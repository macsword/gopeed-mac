import AppKit
import Foundation
import UserNotifications

/// Posts a local notification when a download finishes.
///
/// Held for the app's lifetime by `DownloadStore` (and as a static `shared`),
/// because `UNUserNotificationCenter.delegate` is a weak reference.
@MainActor
final class DownloadNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DownloadNotifier()

    nonisolated static let taskIDKey = "taskID"
    nonisolated static let filePathKey = "filePath"

    private let center = UNUserNotificationCenter.current()
    private var authorizationRequested = false

    /// Called when the user clicks a notification; receives the task id.
    var onOpenTask: ((String) -> Void)?

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Asks once per launch. If the user has denied permission, macOS returns
    /// `false` without prompting and `post` becomes a no-op.
    func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postFinished(taskID: String, name: String, filePath: String?) {
        center.getNotificationSettings { [center] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                break
            default:
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Download complete"
            content.body = name
            content.sound = .default
            var info: [String: String] = [Self.taskIDKey: taskID]
            if let filePath { info[Self.filePathKey] = filePath }
            content.userInfo = info
            let request = UNNotificationRequest(identifier: "gdm.done.\(taskID)", content: content, trigger: nil)
            center.add(request)
        }
    }

    // Show banners even while GDM is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let taskID = info[Self.taskIDKey] as? String
        Task { @MainActor in
            NSApp.activate()
            if let taskID { self.onOpenTask?(taskID) }
            completionHandler()
        }
    }
}
