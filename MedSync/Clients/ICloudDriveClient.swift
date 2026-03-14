import ComposableArchitecture
import Foundation

struct ICloudDriveClient: Sendable {
    var write: @Sendable (_ data: Data, _ plan: ExportFilePlan) throws -> URL
}

enum ICloudDriveError: LocalizedError, Equatable {
    case unavailable
    case fileAlreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "iCloud Drive is unavailable. Sign into iCloud Drive and enable the MedSync container before exporting."
        case let .fileAlreadyExists(path):
            "Refusing to overwrite an existing export at \(path)."
        }
    }
}

extension ICloudDriveClient: DependencyKey {
    static let liveValue = Self(
        write: { data, plan in
            guard let ubiquityRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                throw ICloudDriveError.unavailable
            }

            let documentsRoot = ubiquityRoot.appendingPathComponent("Documents", isDirectory: true)
            let directory = documentsRoot.appendingPathComponent(plan.relativeDirectory, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

            let fileURL = directory.appendingPathComponent(plan.filename)
            guard !FileManager.default.fileExists(atPath: fileURL.path()) else {
                throw ICloudDriveError.fileAlreadyExists(plan.relativePath)
            }

            try data.write(to: fileURL, options: .atomic)
            return fileURL
        }
    )

    static let testValue = Self(
        write: { _, _ in URL(fileURLWithPath: "/tmp/medsync-test.json") }
    )
}

extension DependencyValues {
    var iCloudDrive: ICloudDriveClient {
        get { self[ICloudDriveClient.self] }
        set { self[ICloudDriveClient.self] = newValue }
    }
}

