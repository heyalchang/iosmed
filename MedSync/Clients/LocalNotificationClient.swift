import ComposableArchitecture
import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

enum NotificationAuthorizationState: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unsupported

    var displayName: String {
        switch self {
        case .notDetermined:
            "Not Requested"
        case .denied:
            "Denied"
        case .authorized:
            "Authorized"
        case .provisional:
            "Provisional"
        case .ephemeral:
            "Ephemeral"
        case .unsupported:
            "Unavailable"
        }
    }
}

struct AutomationNotificationPayload: Equatable, Sendable {
    var automationName: String
    var triggerReason: TriggerReason
    var status: ActivityStatus
    var filename: String?
    var errorMessage: String?
}

struct LocalNotificationClient: Sendable {
    var authorizationStatus: @Sendable () async -> NotificationAuthorizationState
    var requestAuthorization: @Sendable () async throws -> NotificationAuthorizationState
    var sendAutomationRunNotification: @Sendable (AutomationNotificationPayload) async -> Void
}

extension LocalNotificationClient: DependencyKey {
    static let liveValue: Self = {
        #if canImport(UserNotifications)
        let service = LocalNotificationService()
        return Self(
            authorizationStatus: {
                await service.authorizationStatus()
            },
            requestAuthorization: {
                try await service.requestAuthorization()
            },
            sendAutomationRunNotification: { payload in
                await service.sendAutomationRunNotification(payload: payload)
            }
        )
        #else
        return Self(
            authorizationStatus: { .unsupported },
            requestAuthorization: { .unsupported },
            sendAutomationRunNotification: { _ in }
        )
        #endif
    }()

    static let testValue = Self(
        authorizationStatus: { .authorized },
        requestAuthorization: { .authorized },
        sendAutomationRunNotification: { _ in }
    )
}

extension DependencyValues {
    var localNotifications: LocalNotificationClient {
        get { self[LocalNotificationClient.self] }
        set { self[LocalNotificationClient.self] = newValue }
    }
}

#if canImport(UserNotifications)
private actor LocalNotificationService {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        return map(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> NotificationAuthorizationState {
        _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return await authorizationStatus()
    }

    func sendAutomationRunNotification(payload: AutomationNotificationPayload) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = payload.automationName
        content.sound = .default

        switch payload.status {
        case .success, .info:
            content.body = "\(payload.triggerReason.displayName) finished\(payload.filename.map { ": \($0)" } ?? ".")"
        case .failure:
            content.body = payload.errorMessage ?? "\(payload.triggerReason.displayName) failed."
        }

        let request = UNNotificationRequest(
            identifier: "automation-run-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    private func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional:
            .provisional
        case .ephemeral:
            .ephemeral
        @unknown default:
            .unsupported
        }
    }
}
#endif
