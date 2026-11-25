import Foundation
import Testing
@testable import SentinelKit

@Suite("MetricKit crash parser")
struct MetricKitCrashParserTests {

    // MARK: - Helpers

    private let parser = MetricKitCrashParser(
        appBinaryName: "Shop",
        options: {
            var options = Options()
            options.environment = "production"
            options.release = "custom-release-of-the-current-build"
            return options
        }(),
        contexts: ContextProvider.contexts(
            app: AppInfo(identifier: "com.example.shop", name: "Shop", version: "3.3.0", build: "500")
        )
    )

    /// 2026-11-24 00:00 → 23:59 UTC, the window of the fixtures.
    private let begin = Date(timeIntervalSince1970: 1_795_478_400)

    private var end: Date {
        begin.addingTimeInterval(86340)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))

        return try Data(contentsOf: url)
    }

    private func delivery(_ name: String) throws -> MetricKitDelivery {
        try MetricKitDelivery(json: fixture(name), begin: begin, end: end)
    }

    /// The fatal-error fixture edited: `transform` receives each diagnostic's metadata by index.
    private func editedFatalError(
        _ transform: (Int, inout [String: Any]) -> Void
    ) throws -> MetricKitDelivery {
        var payload = try JSONSerialization.jsonObject(with: fixture("metrickit-fatal-error")) as? [String: Any] ?? [:]
        var diagnostics = payload["crashDiagnostics"] as? [[String: Any]] ?? []

        for index in diagnostics.indices {
            var metaData = diagnostics[index]["diagnosticMetaData"] as? [String: Any] ?? [:]

            transform(index, &metaData)
            diagnostics[index]["diagnosticMetaData"] = metaData
        }

        payload["crashDiagnostics"] = diagnostics

        return try MetricKitDelivery(json: JSONSerialization.data(withJSONObject: payload), begin: begin, end: end)
    }

    // MARK: - Native crashes

    @Test("turns a segmentation fault into a fatal, unhandled mach exception with the crashed thread's frames")
    func badAccess() throws {
        let result = try parser.parse(delivery("metrickit-bad-access"), handlerCrash: nil)
        let event = try #require(result.events.first)
        let exception = try #require(event.exception?.values.first)
        let frames = try #require(exception.stacktrace?.frames)

        #expect(result.events.count == 1)
        #expect(event.level == .fatal)
        #expect(exception.type == "EXC_BAD_ACCESS")
        #expect(exception.value == "SIGSEGV: Namespace SIGNAL, Code 11 Segmentation fault: 11")
        #expect(exception.mechanism == Mechanism(type: "mach", handled: false))
        #expect(frames.map(\.package) == ["UIKitCore", "Shop", "Shop"])
        #expect(frames.last?.inApp == true)
        #expect(frames.first?.inApp == false)
        #expect(frames.last?.instructionAddress == "0x000000010001e240")
        #expect(frames.last?.imageAddress == "0x0000000100000000")
    }

    @Test("lists each binary once in debug_meta, ready for symbolication")
    func debugImages() throws {
        let event = try #require(try parser.parse(delivery("metrickit-bad-access"), handlerCrash: nil).events.first)
        let images = try #require(event.debugMeta?.images)

        #expect(images.count == 2)
        #expect(images.contains(DebugImage(
            debugID: "a1b2c3d4-0000-1111-2222-333344445555",
            imageAddress: "0x0000000100000000",
            codeFile: "Shop"
        )))
    }

    @Test("uses the build, OS and device that crashed, the payload's own end date and the environment")
    func metadata() throws {
        let event = try #require(try parser.parse(delivery("metrickit-bad-access"), handlerCrash: nil).events.first)

        #expect(event.release == "com.example.shop@3.2.0+412")
        #expect(event.environment == "production")
        #expect(event.timestamp == end)
        #expect(event.contexts?.operatingSystem?.version == "26.1")
        #expect(event.contexts?.operatingSystem?.build == "23B85")
        #expect(event.contexts?.device?.model == "iPhone17,1")
    }

    @Test("without a bundle id in the diagnostic, uses the app's bundle id with the crashed version")
    func releaseWithoutBundleID() throws {
        let edited = try editedFatalError { _, metaData in
            metaData["bundleIdentifier"] = nil
        }

        let event = try #require(try parser.parse(edited, handlerCrash: nil).events.first)

        #expect(event.release == "com.example.shop@3.2.0+412")
    }

    @Test("names Swift runtime traps (fatalError, force unwrap) by their exception and signal")
    func swiftTrap() throws {
        let exception = try #require(
            try parser.parse(delivery("metrickit-fatal-error"), handlerCrash: nil).events.first?.exception?.values.first
        )

        #expect(exception.type == "EXC_BREAKPOINT")
        #expect(exception.value == "SIGTRAP")
        #expect(exception.mechanism?.type == "mach")
    }

    @Test("reports an Objective-C exception the handler did not write, with its name and message")
    func objectiveCWithoutHandler() throws {
        let result = try parser.parse(delivery("metrickit-fatal-error"), handlerCrash: nil)
        let exception = try #require(result.events.last?.exception?.values.first)

        #expect(result.events.count == 2)
        #expect(exception.type == "NSRangeException")
        #expect(exception.value == "*** -[__NSArrayM objectAtIndex:]: index 5 beyond bounds [0 .. 2]")
        #expect(!result.matchedHandlerCrash)
    }

    // MARK: - Deduplication

    @Test("skips the crash the handler already wrote when it falls inside the payload's window")
    func skipsHandlerCrash() throws {
        let result = try parser.parse(delivery("metrickit-fatal-error"), handlerCrash: begin.addingTimeInterval(3600))

        #expect(result.events.count == 1)
        #expect(result.events.first?.exception?.values.first?.type == "EXC_BREAKPOINT")
        #expect(result.matchedHandlerCrash)
    }

    @Test("skips only one diagnostic: a second, real abort in the same payload is still reported")
    func skipsOnlyOnce() throws {
        let edited = try editedFatalError { index, metaData in
            if index == 0 {
                metaData["exceptionType"] = 10
                metaData["signal"] = 6
            }
        }

        let result = try parser.parse(edited, handlerCrash: begin.addingTimeInterval(3600))

        #expect(result.events.count == 1)
        #expect(result.matchedHandlerCrash)
    }

    @Test("does not skip anything when the handler's crash is outside the payload's window")
    func handlerCrashOutsideWindow() throws {
        let result = try parser.parse(delivery("metrickit-fatal-error"), handlerCrash: end.addingTimeInterval(86400))

        #expect(result.events.count == 2)
        #expect(!result.matchedHandlerCrash)
    }

    @Test("a payload without a matching crash leaves the handler's marker for a later payload")
    func noMatchInPayload() throws {
        let result = try parser.parse(delivery("metrickit-bad-access"), handlerCrash: begin.addingTimeInterval(3600))

        #expect(result.events.count == 1)
        #expect(!result.matchedHandlerCrash)
    }

    // MARK: - Robustness

    @Test("skips a diagnostic without metadata and keeps the others")
    func missingMetadata() throws {
        let json = Data(#"{"crashDiagnostics":[{"callStackTree":{}},{"diagnosticMetaData":{"signal":11}}]}"#.utf8)
        let result = try parser.parse(MetricKitDelivery(json: json, begin: begin, end: end), handlerCrash: nil)

        #expect(result.events.count == 1)
        #expect(result.events.first?.exception?.values.first?.type == "SIGSEGV")
        #expect(result.events.first?.exception?.values.first?.mechanism?.type == "signal")
    }

    @Test("rejects a payload that is not MetricKit JSON")
    func invalidPayload() {
        #expect(throws: (any Error).self) {
            try parser.parse(MetricKitDelivery(json: Data("nope".utf8)), handlerCrash: nil)
        }
    }
}
