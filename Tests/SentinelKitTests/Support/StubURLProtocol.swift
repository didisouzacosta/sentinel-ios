import Foundation

/// Answers `URLSession` requests without the network. The reply is read from the request path itself, so there is
/// no shared state between tests:
///
/// - `/status/<code>/…` answers with that status;
/// - `/status/<code>/retry-after/<seconds>/…` also sets `Retry-After`;
/// - `/hang/…` never answers, so the task can only end by cancellation.
final class StubURLProtocol: URLProtocol {

    // MARK: - Public Methods

    /// A real `URLSession` whose requests are served by this stub.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: - URLProtocol

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let segments = url.pathComponents

        guard !segments.contains("hang") else {
            return
        }

        let status = value(after: "status", in: segments).flatMap(Int.init) ?? 200

        var headers = ["Content-Type": "application/json"]

        if let retryAfter = value(after: "retry-after", in: segments) {
            headers["Retry-After"] = retryAfter
        }

        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"status\":\(status)}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Private Methods

    private func value(after key: String, in segments: [String]) -> String? {
        guard let index = segments.firstIndex(of: key), segments.indices.contains(index + 1) else {
            return nil
        }

        return segments[index + 1]
    }
}
