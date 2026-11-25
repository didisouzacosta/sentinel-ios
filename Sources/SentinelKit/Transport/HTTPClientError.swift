/// Failures of `URLSessionHTTPClient` that are not `URLError`s.
enum HTTPClientError: Error, Equatable, Sendable {
    case invalidResponse
}
