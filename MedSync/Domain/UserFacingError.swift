import Foundation

struct UserFacingError: Error, Equatable, Sendable, LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

