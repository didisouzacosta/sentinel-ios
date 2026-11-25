import Foundation

/// `HTTPClient` backed by `URLSession`.
struct URLSessionHTTPClient: HTTPClient {

    // MARK: - Properties

    private let loader: any URLSessionDataLoading

    // MARK: - Initializer

    /// Uses an ephemeral `URLSession` with short timeouts unless a loader is given (tests).
    init(loader: (any URLSessionDataLoading)? = nil) {
        self.loader = loader ?? URLSession(configuration: .sentinel)
    }

    // MARK: - HTTPClient

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (body, response) = try await loader.load(request)

        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, field in
            if let name = field.key as? String, let value = field.value as? String {
                result[name] = value
            }
        }

        return HTTPResponse(statusCode: http.statusCode, headers: headers, body: body)
    }
}

// MARK: - Configuration

extension URLSessionConfiguration {
    /// Ephemeral session (no cookies or cache) with short timeouts: the SDK must never hold the app's network.
    static var sentinel: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return configuration
    }
}
