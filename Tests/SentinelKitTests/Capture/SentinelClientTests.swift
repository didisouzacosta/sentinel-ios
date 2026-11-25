import Foundation
import Testing
@testable import SentinelKit

@Suite("Sentinel client")
struct SentinelClientTests {

    // MARK: - Helpers

    private func makeClient(
        in directory: URL,
        http: any HTTPClient,
        consent: ConsentPolicy = .required,
        stored: ConsentState = .unknown
    ) throws -> Harness {
        var options = Options()
        options.consent = consent

        let store = EventStore(directory: directory)
        let consentStore = TestConsentStore(stored)
        let client = try SentinelClient(
            dsn: DSN("https://pk@sentinel.example.com/1"),
            options: options,
            httpClient: http,
            store: store,
            consentStore: consentStore,
            contexts: Contexts(),
            stackTraceBuilder: StackTraceBuilder(isInApp: { _ in false })
        )

        return Harness(client: client, store: store, consentStore: consentStore)
    }

    private func sentEvent(_ request: URLRequest?) throws -> [String: Any] {
        let body = try #require(request?.httpBody)
        let text = try #require(String(bytes: body, encoding: .utf8))
        let eventLine = try #require(text.components(separatedBy: "\n").dropFirst(2).first)

        return try #require(try JSONSerialization.jsonObject(with: Data(eventLine.utf8)) as? [String: Any])
    }

    // MARK: - Consent

    @Test("with consent required and no decision yet, events stay on the device")
    func waitsForConsent() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http)

            await harness.client.capture(message: "Checkout opened", level: .info)
            await harness.client.flush()

            #expect(try await harness.store.pending().count == 1)
            #expect(await http.requests.isEmpty)
        }
    }

    @Test("granting consent sends what was waiting and remembers the decision")
    func grantConsent() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http)

            await harness.client.capture(message: "Checkout opened", level: .info)
            await harness.client.grantConsent()
            await harness.client.flush()

            #expect(await http.requests.count == 1)
            #expect(try await harness.store.pending().isEmpty)
            #expect(harness.consentStore.load() == .granted)
        }
    }

    @Test("revoking consent deletes what is stored and stops capturing")
    func revokeConsent() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http)

            await harness.client.capture(message: "before", level: .info)
            await harness.client.revokeConsent()
            await harness.client.capture(message: "after", level: .info)
            await harness.client.flush()

            #expect(try await harness.store.pending().isEmpty)
            #expect(await http.requests.isEmpty)
            #expect(harness.consentStore.load() == .revoked)
        }
    }

    @Test("revoking during a send stops delivery: nothing leaves after the request in flight")
    func revokeDuringFlush() async throws {
        try await withTemporaryDirectory { directory in
            let http = GatedHTTPClient()
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            await harness.client.capture(message: "first", level: .info)
            await harness.client.capture(message: "second", level: .info)
            await http.waitForRequests(1)
            await harness.client.revokeConsent()
            await http.waitForCancellations(1)
            await http.releaseAll()
            await harness.client.flush()

            #expect(await http.requests.count == 1)
            #expect(await http.cancellations == 1)
            #expect(try await harness.store.pending().isEmpty)
        }
    }

    @Test("a decision saved in an earlier launch is respected")
    func savedConsent() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http, stored: .granted)

            await harness.client.capture(message: "Checkout opened", level: .info)
            await harness.client.flush()

            #expect(await http.requests.count == 1)
        }
    }

    @Test("with consent not required, events are sent right away")
    func consentNotRequired() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            await harness.client.capture(message: "Checkout opened", level: .info)
            await harness.client.flush()

            #expect(await http.requests.count == 1)
            #expect(try await harness.store.pending().isEmpty)
        }
    }

    // MARK: - Offline

    @Test("offline, keeps the 10 newest events and sends them when the network comes back")
    func offlineQueue() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.failure(.notConnectedToInternet))
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            for index in 1...12 {
                await harness.client.capture(message: "event \(index)", level: .info)
                await harness.client.flush()
            }

            #expect(try await harness.store.pending().count == 10)

            await http.setReply(.status(200))
            await harness.client.connectivityRestored()
            await harness.client.flush()

            let messages = try await http.requests.suffix(10).map { try sentEvent($0)["message"] as? String }

            #expect(try await harness.store.pending().isEmpty)
            #expect(messages.first == "event 3")
            #expect(messages.last == "event 12")
        }
    }

    @Test("if the queue recycles the envelope being sent, delivery goes on with the rest")
    func recycledWhileSending() async throws {
        try await withTemporaryDirectory { directory in
            let http = GatedHTTPClient()
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            await harness.client.capture(message: "event 1", level: .info)
            await http.waitForRequests(1)

            for index in 2...11 {
                await harness.client.capture(message: "event \(index)", level: .info)
            }

            let joined = Task {
                await harness.client.flush()
            }

            await http.open()
            await joined.value

            #expect(await http.requests.count == 11)
            #expect(try await harness.store.pending().isEmpty)
        }
    }

    @Test("an envelope the server rejects is deleted, not retried")
    func rejected() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(400))
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            await harness.client.capture(message: "bad", level: .info)
            await harness.client.flush()

            #expect(try await harness.store.pending().isEmpty)
            #expect(await http.requests.count == 1)
        }
    }

    // MARK: - Content

    @Test("sent events carry breadcrumbs, custom parameters and the error's frames, but no user")
    func content() async throws {
        try await withTemporaryDirectory { directory in
            let http = FakeHTTPClient(.status(200))
            let harness = try makeClient(in: directory, http: http, consent: .notRequired)

            await harness.client.addBreadcrumb(Breadcrumb(category: "ui", message: "Tapped Pay"))
            await harness.client.setCustom("plan", "pro")
            await harness.client.capture(
                error: PaymentError.cardDeclined,
                addresses: StackTraceBuilder.currentAddresses()
            )
            await harness.client.flush()

            let event = try await sentEvent(http.requests.first)
            let exception = try #require((event["exception"] as? [String: Any])?["values"] as? [[String: Any]])

            #expect((event["breadcrumbs"] as? [[String: Any]])?.first?["message"] as? String == "Tapped Pay")
            #expect(event["tags"] as? [String: String] == ["plan": "pro"])
            #expect(exception.first?["type"] as? String == "PaymentError")
            #expect(event["user"] == nil)
        }
    }

    // MARK: - Doubles

    /// Owns the per-test consent suite and removes it when the test ends.
    private final class Harness: Sendable {

        // MARK: - Properties

        let client: SentinelClient

        let store: EventStore

        let consentStore: TestConsentStore

        // MARK: - Lifecycle

        init(client: SentinelClient, store: EventStore, consentStore: TestConsentStore) {
            self.client = client
            self.store = store
            self.consentStore = consentStore
        }

        deinit {
            consentStore.removeSuite()
        }
    }

    private enum PaymentError: Error {
        case cardDeclined
    }
}
