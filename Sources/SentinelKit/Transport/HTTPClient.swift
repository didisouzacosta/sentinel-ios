import Foundation

/// Sends one HTTP request. The SDK talks to the network only through this protocol, so tests use a fake.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}
