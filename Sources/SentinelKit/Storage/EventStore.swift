import Foundation

/// Offline queue: one file per envelope in a directory, oldest first, at most `capacity` files.
///
/// Every event is written here before it is sent, so nothing is lost if the app is closed or the network is down.
/// When the queue is full, the oldest envelope is recycled. Order comes from the file name (wall-clock time, then a
/// sequence number); if the device clock is moved back, the newest envelopes may sort first and be trimmed first.
actor EventStore {

    // MARK: - Constants

    static let defaultCapacity = 10

    private static let fileExtension = "envelope"

    // MARK: - Properties

    private let directory: URL

    private let capacity: Int

    private let now: @Sendable () -> Date

    private var sequence = 0

    // MARK: - Initializer

    init(directory: URL, capacity: Int = defaultCapacity, now: @escaping @Sendable () -> Date = Date.init) {
        self.directory = directory
        self.capacity = capacity
        self.now = now
    }

    /// `Caches/SentinelKit/`, which the system may clear under disk pressure but never backs up.
    static func defaultDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return caches.appendingPathComponent("SentinelKit", isDirectory: true)
    }

    // MARK: - Methods

    func save(_ data: Data, id: EventID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        sequence += 1

        let millis = UInt64(now().timeIntervalSince1970 * 1000)
        let name = String(format: "%013llu-%06ld-%@.%@", millis, sequence % 1_000_000, id.rawValue, Self.fileExtension)

        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        try trimToCapacity()
    }

    /// Envelopes on disk, oldest first.
    func pending() throws -> [StoredEnvelope] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == Self.fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                let id = name.split(separator: "-").last.map(String.init) ?? name

                return StoredEnvelope(id: EventID(rawValue: id), url: url)
            }
    }

    func remove(_ envelope: StoredEnvelope) throws {
        try FileManager.default.removeItem(at: envelope.url)
    }

    func removeAll() throws {
        for envelope in try pending() {
            try remove(envelope)
        }
    }

    // MARK: - Private Methods

    private func trimToCapacity() throws {
        let envelopes = try pending()

        for envelope in envelopes.prefix(max(0, envelopes.count - capacity)) {
            try remove(envelope)
        }
    }
}
