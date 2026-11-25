import Foundation

/// Sends envelopes to the Sentinel ingestion endpoint of a DSN and says what to do with each one.
struct Transport: Sendable {

    // MARK: - Constants

    static let defaultRateLimitDelay: TimeInterval = 60

    // MARK: - Properties

    private let dsn: DSN

    private let client: any HTTPClient

    private let sdk: SDKInfo

    private let encoder = EnvelopeEncoder()

    private let now: @Sendable () -> Date

    // MARK: - Initializer

    init(
        dsn: DSN,
        client: any HTTPClient = URLSessionHTTPClient(),
        sdk: SDKInfo = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.dsn = dsn
        self.client = client
        self.sdk = sdk
        self.now = now
    }

    // MARK: - Methods

    /// Sends one envelope. Network failures become `.retryLater` and are never thrown; what is thrown is
    /// cancellation (`CancellationError`) or an envelope that cannot be encoded.
    func send(_ envelope: Envelope) async throws -> TransportResult {
        let request = try makeRequest(for: envelope)

        let response: HTTPResponse

        do {
            response = try await client.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .retryLater(after: nil)
        }

        return result(for: response)
    }

    // MARK: - Private Methods

    private func makeRequest(for envelope: Envelope) throws -> URLRequest {
        var request = URLRequest(url: dsn.envelopeURL)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(envelope)
        request.setValue("application/x-sentry-envelope", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Sentry sentry_version=7, sentry_client=\(sdk.name)/\(sdk.version), sentry_key=\(dsn.publicKey)",
            forHTTPHeaderField: "X-Sentry-Auth"
        )
        return request
    }

    private func result(for response: HTTPResponse) -> TransportResult {
        let retryAfter = RetryAfter.seconds(from: response.header("Retry-After"), now: now())

        switch response.statusCode {
        case 200..<300:
            return .accepted

        case 429:
            return .rateLimited(retryAfter: retryAfter ?? Self.defaultRateLimitDelay)

        case 400..<500:
            return .rejected(statusCode: response.statusCode)

        default:
            return .retryLater(after: retryAfter)
        }
    }
}
