import Foundation
import Testing
@testable import SentinelKit

@Suite("Sentinel hub")
struct SentinelHubTests {

    // MARK: - Helpers

    private let dsn = "https://pk@sentinel.example.com/1"

    private func makeHub(store: EventStore, consentStore: TestConsentStore, http: any HTTPClient) -> SentinelHub {
        SentinelHub(consentStore: consentStore, store: store, observesSystem: false) { dsn, options, consent, store in
            guard let dsn = try? DSN(dsn) else {
                return nil
            }

            return SentinelClient(
                dsn: dsn,
                options: options,
                httpClient: http,
                store: store,
                consentStore: consent,
                contexts: Contexts(),
                stackTraceBuilder: StackTraceBuilder(isInApp: { _ in false })
            )
        }
    }

    private func flush(_ hub: SentinelHub) async {
        await withCheckedContinuation { continuation in
            hub.send(.flush(continuation))
        }
    }

    private func barrier(_ hub: SentinelHub) async {
        await withCheckedContinuation { continuation in
            hub.send(.barrier(continuation))
        }
    }

    // MARK: - Ordering

    @Test("processes calls in the order they were made")
    func order() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore(.granted)
            let http = FakeHTTPClient(.status(200))
            let hub = makeHub(store: EventStore(directory: directory), consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            hub.send(.start(dsn: dsn, options: Options()))
            hub.send(.breadcrumb(Breadcrumb(category: "ui", message: "Tapped Pay")))
            hub.send(.custom("plan", "pro"))
            hub.send(.captureMessage("Checkout failed", .error))
            await flush(hub)

            let body = try #require(await http.requests.first?.httpBody)
            let text = try #require(String(bytes: body, encoding: .utf8))

            #expect(text.contains("\"message\":\"Tapped Pay\""))
            #expect(text.contains("\"plan\":\"pro\""))
            #expect(text.contains("\"message\":\"Checkout failed\""))
        }
    }

    @Test("a flush waiting for the network does not hold the next calls")
    func flushDoesNotBlock() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore(.granted)
            let http = GatedHTTPClient()
            let store = EventStore(directory: directory)
            let hub = makeHub(store: store, consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            hub.send(.start(dsn: dsn, options: Options()))
            hub.send(.captureMessage("first", .info))

            let waiting = Task {
                await flush(hub)
            }

            await http.waitForRequests(1)
            hub.send(.captureMessage("second", .info))
            await barrier(hub)

            let storedWhileSending = try await store.pending().count

            #expect(storedWhileSending == 2)

            // The flush sends "first", then (another pass) "second": release both before waiting for it.
            await http.releaseAll()
            await http.waitForRequests(2)
            await http.releaseAll()
            await waiting.value
        }
    }

    // MARK: - Lifecycle

    @Test("ignores captures before start, and a second start")
    func startRules() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore(.granted)
            let http = FakeHTTPClient(.status(200))
            let hub = makeHub(store: EventStore(directory: directory), consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            hub.send(.captureMessage("too early", .info))
            hub.send(.start(dsn: dsn, options: Options()))
            hub.send(.start(dsn: "https://other@sentinel.example.com/2", options: Options()))
            hub.send(.captureMessage("after start", .info))
            await flush(hub)

            let requests = await http.requests

            #expect(requests.count == 1)
            #expect(requests.first?.url?.absoluteString == "https://sentinel.example.com/api/1/envelope/")
        }
    }

    @Test("an invalid DSN leaves the SDK off without crashing")
    func invalidDSN() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore(.granted)
            let http = FakeHTTPClient(.status(200))
            let hub = makeHub(store: EventStore(directory: directory), consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            hub.send(.start(dsn: "not a dsn", options: Options()))
            hub.send(.captureMessage("ignored", .info))
            await flush(hub)

            #expect(await http.requests.isEmpty)
        }
    }

    // MARK: - Consent before start

    @Test("a revoke before start is saved, clears the queue and wins over an earlier grant")
    func revokeBeforeStart() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore(.granted)
            let http = FakeHTTPClient(.status(200))
            let store = EventStore(directory: directory)
            let hub = makeHub(store: store, consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            try await store.save(Data("left from an earlier launch".utf8), id: EventID())
            hub.send(.revokeConsent)
            hub.send(.start(dsn: dsn, options: Options()))
            hub.send(.captureMessage("must not be stored", .info))
            await flush(hub)

            #expect(consentStore.load() == .revoked)
            #expect(try await store.pending().isEmpty)
            #expect(await http.requests.isEmpty)
        }
    }

    @Test("a grant before start is saved and used once the SDK starts")
    func grantBeforeStart() async throws {
        try await withTemporaryDirectory { directory in
            let consentStore = TestConsentStore()
            let http = FakeHTTPClient(.status(200))
            let hub = makeHub(store: EventStore(directory: directory), consentStore: consentStore, http: http)

            defer {
                consentStore.removeSuite()
            }

            hub.send(.grantConsent)
            hub.send(.start(dsn: dsn, options: Options()))
            hub.send(.captureMessage("sent", .info))
            await flush(hub)

            #expect(consentStore.load() == .granted)
            #expect(await http.requests.count == 1)
        }
    }
}
