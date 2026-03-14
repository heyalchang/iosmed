import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var notificationStatus: NotificationAuthorizationState = .notDetermined
        var statusMessage: String?
    }

    enum Action: Equatable {
        case task
        case notificationStatusResponse(NotificationAuthorizationState)
        case requestNotificationPermissionTapped
        case requestNotificationPermissionResponse(Result<NotificationAuthorizationState, UserFacingError>)
        case requestHealthKitAccessTapped
        case requestHealthKitAccessResponse(Result<String, UserFacingError>)
    }

    @Dependency(\.localNotifications) var localNotifications
    @Dependency(\.healthKitClient) var healthKitClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let status = await localNotifications.authorizationStatus()
                    await send(.notificationStatusResponse(status))
                }

            case let .notificationStatusResponse(status):
                state.notificationStatus = status
                return .none

            case .requestNotificationPermissionTapped:
                return .run { send in
                    do {
                        let status = try await localNotifications.requestAuthorization()
                        await send(.requestNotificationPermissionResponse(.success(status)))
                    } catch {
                        await send(.requestNotificationPermissionResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .requestNotificationPermissionResponse(.success(status)):
                state.notificationStatus = status
                state.statusMessage = "Notification permission is \(status.displayName.lowercased())."
                return .none

            case let .requestNotificationPermissionResponse(.failure(error)):
                state.statusMessage = error.message
                return .none

            case .requestHealthKitAccessTapped:
                return .run { send in
                    do {
                        try await healthKitClient.requestAuthorization()
                        await send(.requestHealthKitAccessResponse(.success("HealthKit access is ready for medication exports.")))
                    } catch {
                        await send(.requestHealthKitAccessResponse(.failure(UserFacingError(error.localizedDescription))))
                    }
                }

            case let .requestHealthKitAccessResponse(.success(message)):
                state.statusMessage = message
                return .none

            case let .requestHealthKitAccessResponse(.failure(error)):
                state.statusMessage = error.message
                return .none
            }
        }
    }
}
