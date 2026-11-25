import Foundation
import Testing
@testable import SentinelKit

/// End to end against a real Sentinel server, through the real `URLSession`. Skipped unless `SENTINEL_DSN` is set:
///
/// ```sh
/// SENTINEL_DSN="http://<key>@127.0.0.1:8787/<id>" SENTINEL_API_TOKEN="wst_…" swift test --filter LiveServer
/// ```
///
/// With `SENTINEL_API_TOKEN` (Settings → API tokens) the test also reads the event back through `/api/0`.
@Suite("Live server", .enabled(if: LiveServerEnvironment.dsn != nil))
struct LiveServerTests {

    // MARK: - Helpers

    private func makeEvent() -> Event {
        var scope = Scope()

        let builder = EventBuilder(
            options: {
                var options = Options()
                options.environment = "integration"
                return options
            }(),
            contexts: ContextProvider.contexts(
                app: AppInfo(identifier: "com.example.integration", name: "Integration", version: "1.0", build: "1")
            ),
            stackTraceBuilder: .app
        )

        scope.add(Breadcrumb(timestamp: Date(), category: "test", message: "Live server test", level: .info))
        scope.setCustom("run", UUID().uuidString)

        return builder.event(
            for: LiveError(),
            addresses: StackTraceBuilder.currentAddresses(),
            scope: scope,
            at: Date()
        )
    }

    /// `GET /api/0/organizations/sentinel/eventids/<id>/` → HTTP status.
    private func lookUp(_ eventID: EventID, dsn: DSN, token: String) async throws -> Int {
        var components = try #require(URLComponents(url: dsn.envelopeURL, resolvingAgainstBaseURL: false))
        components.path = "/api/0/organizations/sentinel/eventids/\(eventID.rawValue)/"

        var request = try URLRequest(url: #require(components.url))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await URLSessionHTTPClient().send(request).statusCode
    }

    // MARK: - Delivery

    @Test("the server accepts an event built by the SDK and finds it by id")
    func deliversEvent() async throws {
        let dsn = try DSN(#require(LiveServerEnvironment.dsn))
        let event = makeEvent()
        let result = try await Transport(dsn: dsn).send(Envelope(event: event))

        #expect(result == .accepted)

        if let token = LiveServerEnvironment.apiToken {
            let status = try await lookUp(event.eventID, dsn: dsn, token: token)

            #expect(status == 200)
        }
    }

    // MARK: - Doubles

    private struct LiveError: Error {}
}
