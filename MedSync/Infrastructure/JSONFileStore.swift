import Foundation

actor JSONFileStore<Value: Codable & Sendable> {
    private let filename: String
    private let defaultValue: Value
    private let directoryURL: URL?

    init(filename: String, defaultValue: Value, directoryURL: URL? = nil) {
        self.filename = filename
        self.defaultValue = defaultValue
        self.directoryURL = directoryURL
    }

    func load() throws -> Value {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return defaultValue
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder.medSync.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let url = try fileURL()
        let data = try JSONEncoder.medSync.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func fileURL() throws -> URL {
        let directory: URL
        if let directoryURL {
            directory = directoryURL
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = appSupport.appendingPathComponent("MedSync", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename)
    }
}
