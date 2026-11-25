import Foundation

/// Writes a crash to the offline queue synchronously, from the crashing thread. It is sent on the next launch.
enum CrashWriter {

    // MARK: - Constants

    /// Left next to the queue, with the crash time, so MetricKit's report of the same crash is skipped.
    static let markerName = "nsexception.marker"

    /// A marker older than this no longer matches any MetricKit payload and is removed.
    static let markerLifetime: TimeInterval = 7 * 24 * 3600

    /// Sorts the crash after anything saved in the same millisecond.
    private static let crashSequence = 999_999

    // MARK: - Methods

    /// `true` when the crash was written.
    @discardableResult
    static func write(
        exceptionName: String,
        reason: String,
        addresses: [UInt],
        snapshot: CrashSnapshot,
        now: Date = Date()
    ) -> Bool {
        guard snapshot.consentAllowsCapture else {
            return false
        }

        let builder = EventBuilder(
            options: snapshot.options,
            contexts: snapshot.contexts,
            stackTraceBuilder: snapshot.stackTraceBuilder
        )
        let event = builder.event(
            exceptionName: exceptionName,
            reason: reason,
            addresses: addresses,
            scope: snapshot.scope,
            at: now
        )

        do {
            let envelope = try Envelope(event: event, sentAt: now)

            try EventStore.write(
                EnvelopeEncoder().encode(envelope),
                id: event.eventID,
                sequence: crashSequence,
                to: snapshot.location,
                date: now
            )
            try Data(String(now.timeIntervalSince1970).utf8)
                .write(to: snapshot.location.directory.appendingPathComponent(markerName), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// When the handler last wrote a crash, if its marker is still valid. Unreadable or expired markers are removed.
    static func handlerCrashDate(in directory: URL, now: Date = Date()) -> Date? {
        let marker = directory.appendingPathComponent(markerName)

        guard FileManager.default.fileExists(atPath: marker.path) else {
            return nil
        }

        guard
            let text = try? String(contentsOf: marker, encoding: .utf8), let seconds = TimeInterval(text),
            now.timeIntervalSince1970 - seconds < markerLifetime
        else {
            removeMarker(in: directory)
            return nil
        }

        return Date(timeIntervalSince1970: seconds)
    }

    static func removeMarker(in directory: URL) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(markerName))
    }
}
