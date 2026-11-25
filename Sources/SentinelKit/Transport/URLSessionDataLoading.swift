import Foundation

/// The single `URLSession` call the SDK needs, behind a protocol so `URLSessionHTTPClient` is testable
/// without the network.
protocol URLSessionDataLoading: Sendable {
    func load(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataLoading {
    func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
