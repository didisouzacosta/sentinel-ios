import Foundation
import Testing
@testable import SentinelKit

@Suite("Transport")
struct TransportTests {

    // MARK: - Helpers

    private func envelope() throws -> Envelope {
        try Envelope(event: EventFixtures.message, sentAt: EventFixtures.timestamp)
    }

    private func send(_ reply: FakeHTTPClient.Reply) async throws -> (TransportResult, FakeHTTPClient) {
        let client = FakeHTTPClient(reply)
        let dsn = try DSN("https://pk123@sentinel.example.com/42")
        let transport = Transport(dsn: dsn, client: client, sdk: EventFixtures.sdk)
        let result = try await transport.send(envelope())

        return (result, client)
    }

    // MARK: - Request

    @Test("posts the encoded envelope to the DSN endpoint with Sentry auth")
    func request() async throws {
        let (_, client) = try await send(.status(200))
        let request = try #require(await client.requests.first)
        let auth = try #require(request.value(forHTTPHeaderField: "X-Sentry-Auth"))

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://sentinel.example.com/api/42/envelope/")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-sentry-envelope")
        #expect(auth.hasPrefix("Sentry "))
        #expect(auth.contains("sentry_version=7"))
        #expect(auth.contains("sentry_key=pk123"))
        #expect(auth.contains("sentry_client=sentinel.cocoa/0.1.0"))
        #expect(try request.httpBody == (EnvelopeEncoder().encode(envelope())))
    }

    // MARK: - Responses

    @Test("200 means accepted")
    func accepted() async throws {
        let (result, _) = try await send(.status(200))

        #expect(result == .accepted)
    }

    @Test("429 waits for Retry-After, or 60 seconds without it")
    func rateLimited() async throws {
        let (withHeader, _) = try await send(.status(429, headers: ["Retry-After": "120"]))
        let (withoutHeader, _) = try await send(.status(429))

        #expect(withHeader == .rateLimited(retryAfter: 120))
        #expect(withoutHeader == .rateLimited(retryAfter: 60))
    }

    @Test("503 and other 5xx keep the envelope to retry later")
    func serverErrors() async throws {
        let (unavailable, _) = try await send(.status(503, headers: ["retry-after": "5"]))
        let (internalError, _) = try await send(.status(500))

        #expect(unavailable == .retryLater(after: 5))
        #expect(internalError == .retryLater(after: nil))
    }

    @Test("4xx other than 429 drops the envelope", arguments: [400, 401, 403, 413])
    func rejected(status: Int) async throws {
        let (result, _) = try await send(.status(status))

        #expect(result == .rejected(statusCode: status))
    }

    @Test("network failures keep the envelope to retry later")
    func networkFailure() async throws {
        let (result, _) = try await send(.failure(.notConnectedToInternet))

        #expect(result == .retryLater(after: nil))
    }

    @Test("cancellation is propagated, not swallowed")
    func cancellation() async throws {
        await #expect(throws: CancellationError.self) {
            _ = try await send(.cancelled)
        }
    }

    @Test("URLSession's cancellation (URLError.cancelled) is also propagated, so the envelope is kept")
    func urlSessionCancellation() async throws {
        await #expect(throws: CancellationError.self) {
            _ = try await send(.failure(.cancelled))
        }
    }

    // MARK: - Real URLSession

    @Test("sends through a real URLSession and maps its responses", arguments: [
        ("https://pk@stub.test/status/200/1", TransportResult.accepted),
        ("https://pk@stub.test/status/429/retry-after/30/1", .rateLimited(retryAfter: 30)),
        ("https://pk@stub.test/status/503/1", .retryLater(after: nil)),
        ("https://pk@stub.test/status/401/1", .rejected(statusCode: 401)),
    ])
    func realSession(dsn: String, expected: TransportResult) async throws {
        let client = URLSessionHTTPClient(loader: StubURLProtocol.session())
        let transport = try Transport(dsn: DSN(dsn), client: client, sdk: EventFixtures.sdk)

        #expect(try await transport.send(envelope()) == expected)
    }

    @Test("cancelling a send on a real URLSession throws CancellationError")
    func realSessionCancellation() async throws {
        let client = URLSessionHTTPClient(loader: StubURLProtocol.session())
        let transport = try Transport(dsn: DSN("https://pk@stub.test/hang/1"), client: client, sdk: EventFixtures.sdk)
        let envelope = try envelope()
        let task = Task {
            try await transport.send(envelope)
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
