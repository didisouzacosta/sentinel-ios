import Foundation

/// Runs `body` with a fresh empty directory and removes it afterwards.
func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SentinelKitTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    return try await body(directory)
}
