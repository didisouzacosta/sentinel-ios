import Foundation
@testable import SentinelKit

/// Records every request and answers with a scripted status, headers or error.
actor FakeHTTPClient: HTTPClient {

    // MARK: - Properties

    private var reply: Reply

    private(set) var requests: [URLRequest] = []

    // MARK: - Initializer

    init(_ reply: Reply) {
        self.reply = reply
    }

    // MARK: - Methods

    /// Changes the answer for the next requests (for example, the network coming back).
    func setReply(_ reply: Reply) {
        self.reply = reply
    }

    // MARK: - HTTPClient

    func send(_ request: URLRequest) throws -> HTTPResponse {
        requests.append(request)

        switch reply {
        case let .status(code, headers):
            return HTTPResponse(statusCode: code, headers: headers, body: Data())

        case let .failure(code):
            throw URLError(code)

        case .cancelled:
            throw CancellationError()
        }
    }

    // MARK: - Types

    enum Reply: Sendable {
        case status(Int, headers: [String: String] = [:])
        case failure(URLError.Code)
        case cancelled
    }
}
