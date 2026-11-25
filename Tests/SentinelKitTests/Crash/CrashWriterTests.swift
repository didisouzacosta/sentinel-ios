import Foundation
import Testing
@testable import SentinelKit

@Suite("Crash writer")
struct CrashWriterTests {

    // MARK: - Helpers

    private func snapshot(in directory: URL, consentAllowsCapture: Bool = true) -> CrashSnapshot {
        var options = Options()
        options.release = "com.example.shop@3.2.0+412"

        var scope = Scope()
        scope.add(Breadcrumb(category: "ui", message: "Tapped Pay"))
        scope.setCustom("plan", "pro")

        return CrashSnapshot(
            location: QueueLocation(directory: directory, capacity: 10),
            options: options,
            contexts: Contexts(),
            scope: scope,
            consentAllowsCapture: consentAllowsCapture,
            stackTraceBuilder: StackTraceBuilder(isInApp: { _ in false })
        )
    }

    private func writeCrash(_ snapshot: CrashSnapshot) -> Bool {
        CrashWriter.write(
            exceptionName: "NSRangeException",
            reason: "index 5 beyond bounds [0 .. 2]",
            addresses: StackTraceBuilder.currentAddresses(),
            snapshot: snapshot
        )
    }

    private func event(at url: URL) throws -> [String: Any] {
        let text = try #require(String(bytes: Data(contentsOf: url), encoding: .utf8))
        let line = try #require(text.components(separatedBy: "\n").dropFirst(2).first)

        return try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    }

    // MARK: - Writing

    @Test("writes the crash to the queue synchronously, with breadcrumbs and custom parameters")
    func writesCrash() async throws {
        try await withTemporaryDirectory { directory in
            #expect(writeCrash(snapshot(in: directory)))

            let pending = try await EventStore(directory: directory).pending()
            let event = try event(at: #require(pending.first).url)
            let exception = try #require((event["exception"] as? [String: Any])?["values"] as? [[String: Any]])
            let mechanism = try #require(exception.first?["mechanism"] as? [String: Any])

            #expect(pending.count == 1)
            #expect(event["level"] as? String == "fatal")
            #expect(exception.first?["type"] as? String == "NSRangeException")
            #expect(exception.first?["value"] as? String == "index 5 beyond bounds [0 .. 2]")
            #expect(mechanism["type"] as? String == "NSException")
            #expect(mechanism["handled"] as? Bool == false)
            #expect((event["breadcrumbs"] as? [[String: Any]])?.first?["message"] as? String == "Tapped Pay")
            #expect(event["tags"] as? [String: String] == ["plan": "pro"])
            #expect(event["release"] as? String == "com.example.shop@3.2.0+412")
        }
    }

    @Test("keeps the queue at 10, with the crash as the newest envelope")
    func respectsCapacity() async throws {
        try await withTemporaryDirectory { directory in
            let store = EventStore(directory: directory)

            for index in 1...10 {
                try await store.save(Data("envelope \(index)".utf8), id: EventID())
            }

            #expect(writeCrash(snapshot(in: directory)))

            let pending = try await store.pending()
            let newest = try String(contentsOf: #require(pending.last).url, encoding: .utf8)

            #expect(pending.count == 10)
            #expect(newest.contains("NSRangeException"))
        }
    }

    @Test("writes nothing when the user revoked consent")
    func revoked() async throws {
        try await withTemporaryDirectory { directory in
            #expect(!writeCrash(snapshot(in: directory, consentAllowsCapture: false)))

            let pending = try await EventStore(directory: directory).pending()

            #expect(pending.isEmpty)
        }
    }

    // MARK: - Marker

    @Test("leaves a marker with the crash time, so MetricKit's report of the same crash can be matched")
    func marker() async throws {
        try await withTemporaryDirectory { directory in
            let crashTime = Date(timeIntervalSince1970: 1_795_500_000)

            #expect(CrashWriter.handlerCrashDate(in: directory) == nil)
            #expect(CrashWriter.write(
                exceptionName: "NSRangeException",
                reason: "boom",
                addresses: [],
                snapshot: snapshot(in: directory),
                now: crashTime
            ))
            #expect(CrashWriter.handlerCrashDate(in: directory, now: crashTime) == crashTime)

            CrashWriter.removeMarker(in: directory)

            #expect(CrashWriter.handlerCrashDate(in: directory, now: crashTime) == nil)
        }
    }

    @Test("removes a marker older than a week, so it cannot hide a later crash")
    func staleMarker() async throws {
        try await withTemporaryDirectory { directory in
            let crashTime = Date(timeIntervalSince1970: 1_795_500_000)

            CrashWriter.write(
                exceptionName: "NSRangeException",
                reason: "boom",
                addresses: [],
                snapshot: snapshot(in: directory),
                now: crashTime
            )

            #expect(CrashWriter.handlerCrashDate(in: directory, now: crashTime.addingTimeInterval(8 * 86400)) == nil)
            #expect(CrashWriter.handlerCrashDate(in: directory, now: crashTime) == nil)
        }
    }

    @Test("the snapshot store returns the latest snapshot")
    func snapshotStore() async throws {
        try await withTemporaryDirectory { directory in
            let store = CrashSnapshotStore()

            #expect(store.current == nil)

            store.update(snapshot(in: directory))

            #expect(store.current?.scope.custom == ["plan": "pro"])
        }
    }
}
