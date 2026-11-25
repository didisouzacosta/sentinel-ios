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

    /// Also read by the crash writer, which must write synchronously while the app is crashing.
    nonisolated let location: QueueLocation

    nonisolated var directory: URL {
        location.directory
    }

    private let now: @Sendable () -> Date

    private var sequence = 0

    // MARK: - Initializer

    init(directory: URL, capacity: Int = defaultCapacity, now: @escaping @Sendable () -> Date = Date.init) {
        location = QueueLocation(directory: directory, capacity: capacity)
        self.now = now
    }

    // MARK: - Type Methods

    /// `Caches/SentinelKit/`, which the system may clear under disk pressure but never backs up.
    static func defaultDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return caches.appendingPathComponent("SentinelKit", isDirectory: true)
    }

    /// Writes one envelope and trims the queue. Synchronous so the crash handler can use it while the app dies.
    static func write(_ data: Data, id: EventID, sequence: Int, to location: QueueLocation, date: Date) throws {
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)

        let millis = UInt64(date.timeIntervalSince1970 * 1000)
        let name = String(format: "%013llu-%06ld-%@.%@", millis, sequence % 1_000_000, id.rawValue, fileExtension)

        try data.write(to: location.directory.appendingPathComponent(name), options: .atomic)

        let envelopes = try pending(in: location.directory)

        // A flush may remove a file at the same time (even while the app crashes): missing files are fine.
        for envelope in envelopes.prefix(max(0, envelopes.count - location.capacity)) {
            try? FileManager.default.removeItem(at: envelope.url)
        }
    }

    /// Envelopes in `directory`, oldest first.
    static func pending(in directory: URL) throws -> [StoredEnvelope] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                let id = name.split(separator: "-").last.map(String.init) ?? name

                return StoredEnvelope(id: EventID(rawValue: id), url: url)
            }
    }

    // MARK: - Methods

    func save(_ data: Data, id: EventID) throws {
        sequence += 1

        try Self.write(data, id: id, sequence: sequence, to: location, date: now())
    }

    /// Envelopes on disk, oldest first.
    func pending() throws -> [StoredEnvelope] {
        try Self.pending(in: directory)
    }

    func remove(_ envelope: StoredEnvelope) throws {
        try FileManager.default.removeItem(at: envelope.url)
    }

    func removeAll() throws {
        for envelope in try pending() {
            try remove(envelope)
        }
    }
}
