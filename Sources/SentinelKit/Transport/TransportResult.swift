import Foundation

/// What to do with an envelope after trying to send it.
enum TransportResult: Equatable, Sendable {
    /// Stored by the server; delete it locally.
    case accepted
    /// Too many events; keep it and wait before sending anything else.
    case rateLimited(retryAfter: TimeInterval)
    /// Network failure or server error; keep it and retry later.
    case retryLater(after: TimeInterval?)
    /// The server refused it (bad request, invalid key, too large); retrying would not help, so drop it.
    case rejected(statusCode: Int)
}
