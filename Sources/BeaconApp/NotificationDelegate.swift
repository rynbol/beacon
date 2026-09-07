import AppKit
import UserNotifications
import BeaconKit

/// Receives taps on notification buttons.
///
/// This object is the only path by which an alert that has already fired can
/// hand the app any execution time. A delivered notification that is ignored
/// wakes nothing, so every Complete, every Snooze and every swipe-away is also
/// the moment the whole plan gets rebuilt.
@MainActor
final class NotificationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    let model = TaskListModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Assigned before launch finishes, or a response that arrives while the
        // app is starting is dropped.
        UNUserNotificationCenter.current().delegate = self

        // The harness runs from here, not from the window's `.task`. SwiftUI
        // holds `.task` until a window actually appears, so a launch that never
        // shows one — which is every headless run of these tools — sat idle and
        // wrote nothing at all.
        if E2ECheck.isCleanupOnly {
            Task { exit(await E2ECheck.runCleanupOnly()) }
        } else if E2ECheck.isRequested {
            Task { exit(await E2ECheck.run()) }
        } else {
            Task { await model.start() }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let key = response.notification.request.content.userInfo["taskKey"] as? String
        await handle(action: action, key: key)
    }

    private func handle(action: String, key: String?) async {
        guard !E2ECheck.isHarnessRun else { return }
        // Wait for the shared model even when the action launched the app.
        await model.start()
        await model.refresh()

        if action == UNNotificationDefaultActionIdentifier {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Dismissal leaves the next reminders armed. It is not a request to
        // change the reminder's due date or advance its snooze history.
        guard action != UNNotificationDismissActionIdentifier,
              let key, let task = model.task(withKey: key), !task.isCompleted else { return }

        switch action {
        case NotificationScheduler.Action.complete.rawValue:
            await model.complete(task)
        case NotificationScheduler.Action.snooze.rawValue:
            await model.snoozeOneRung(task, extra: 0)
        case NotificationScheduler.Action.snoozeLonger.rawValue:
            await model.snoozeOneRung(task, extra: 1)
        default:
            break
        }
    }
}
