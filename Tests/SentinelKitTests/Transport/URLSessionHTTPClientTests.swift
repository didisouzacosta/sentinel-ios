import Foundation
import Testing
@testable import SentinelKit

@Suite("URLSession HTTP client")
struct URLSessionHTTPClientTests {

    // MARK: - Properties

    private let url = URL(fileURLWithPath: "/api/1/envelope/")

    // MARK: - Behaviour

    @Test("returns status, headers and body from a real URLSession")
    func httpResponse() async throws {
        let stubURL = try #require(URL(string: "https://stub.test/status/429/retry-after/30/api/1/envelope/"))
        let client = URLSessionHTTPClient(loader: StubURLProtocol.session())
        let result = try await client.send(URLRequest(url: stubURL))

        #expect(result.statusCode == 429)
        #expect(result.header("retry-after") == "30")
        #expect(result.body == Data("{\"status\":429}".utf8))
    }

    @Test("fails when the response is not HTTP")
    func nonHTTPResponse() async throws {
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        let client = URLSessionHTTPClient(loader: FakeLoader(response: response, body: Data()))

        await #expect(throws: HTTPClientError.invalidResponse) {
            _ = try await client.send(URLRequest(url: url))
        }
    }

    // MARK: - Doubles

    private struct FakeLoader: URLSessionDataLoading {
        let response: URLResponse
        let body: Data

        func load(_ request: URLRequest) throws -> (Data, URLResponse) {
            (body, response)
        }
    }
}
