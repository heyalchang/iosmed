import Foundation

actor JSONFileStore<Value: Codable & Sendable> {
    private let filename: String
    private let defaultValue: Value

    init(filename: String, defaultValue: Value) {
        self.filename = filename
        self.defaultValue = defaultValue
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
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("MedSync", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename)
    }
}
