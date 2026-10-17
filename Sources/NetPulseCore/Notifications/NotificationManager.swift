import Foundation
import UserNotifications
import AppKit

@MainActor
public protocol NotificationManaging: AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func sendDisconnectionNotification(at date: Date, reason: String?, language: AppLanguage)
    func sendReconnectionNotification(downtime: TimeInterval?, language: AppLanguage)
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}

@MainActor
public final class NotificationManager: NotificationManaging {
    public static let shared = NotificationManager()

    private let center: UNUserNotificationCenter
    private let settings: SettingsManager
    private let delegate = NotificationDelegate()
    private var lastDisconnectNotificationDate: Date = .distantPast
    private var lastReconnectNotificationDate: Date = .distantPast

    @MainActor
    public init(
        center: UNUserNotificationCenter = .current(),
        settings: SettingsManager? = nil
    ) {
        self.center = center
        self.settings = settings ?? .shared
        self.center.delegate = self.delegate
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func sendDisconnectionNotification(at date: Date, reason: String?, language: AppLanguage) {
        guard settings.notificationsEnabled && settings.notifyOnDisconnect else { return }

        let now = Date()
        if now.timeIntervalSince(lastDisconnectNotificationDate) < settings.notificationCooldown {
            return
        }
        lastDisconnectNotificationDate = now

        let title = L10n.string(.notifDisconnectTitle, language: language)
        var body = L10n.string(.notifDisconnectBody, language: language)
        if let reason = reason, !reason.isEmpty {
            body += " (\(reason))"
        }

        deliver(title: title, body: body)
    }

    public func sendReconnectionNotification(downtime: TimeInterval?, language: AppLanguage) {
        guard settings.notificationsEnabled && settings.notifyOnReconnect else { return }

        let now = Date()
        if now.timeIntervalSince(lastReconnectNotificationDate) < settings.notificationCooldown {
            return
        }
        lastReconnectNotificationDate = now

        let title = L10n.string(.notifReconnectTitle, language: language)
        let body: String
        if settings.includeDowntimeInNotification, let downtime = downtime, downtime > 0 {
            let formattedDuration = OutageRecord.formatDuration(downtime, language: language)
            body = String(format: L10n.string(.notifReconnectBodyWithDowntime, language: language), formattedDuration)
        } else {
            body = L10n.string(.notifReconnectBody, language: language)
        }

        deliver(title: title, body: body)
    }

    private func deliver(title: String, body: String) {
        if settings.playNotificationSounds {
            if let glass = NSSound(named: "Glass") {
                glass.play()
            } else {
                NSSound.beep()
            }
        }

        // 1. Native UNUserNotificationCenter request
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if settings.playNotificationSounds {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "ir.kamandlou.NetPulse.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            try? await center.add(request)
        }

        // 2. Guaranteed out-of-process system banner via osascript
        deliverSystemBanner(title: title, body: body)
    }

    private func deliverSystemBanner(title: String, body: String) {
        let cleanTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let cleanBody = body
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "display notification \"\(cleanBody)\" with title \"NetPulse\" subtitle \"\(cleanTitle)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
