import Foundation

/// Status, headers and body of an HTTP response.
struct HTTPResponse: Sendable, Equatable {

    // MARK: - Properties

    let statusCode: Int

    let headers: [String: String]

    let body: Data

    // MARK: - Methods

    /// Header value, matching the name case-insensitively.
    func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
