import Foundation

/// When the SDK may send: respects the server's rate limit and backs off after network failures
/// (30 s, 60 s, 120 s… up to one hour).
struct DeliveryState: Sendable {

    // MARK: - Constants

    static let initialBackoff: TimeInterval = 30

    static let maxBackoff: TimeInterval = 3600

    // MARK: - Properties

    private var rateLimitedUntil: Date?

    private var backoffUntil: Date?

    private var networkFailures = 0

    // MARK: - Methods

    /// When sending may resume, or `nil` when nothing blocks it.
    var nextAttempt: Date? {
        [rateLimitedUntil, backoffUntil].compactMap(\.self).max()
    }

    func canSend(at date: Date) -> Bool {
        [rateLimitedUntil, backoffUntil].allSatisfy { limit in
            limit.map { date >= $0 } ?? true
        }
    }

    mutating func record(_ result: TransportResult, at date: Date) -> DeliveryAction {
        switch result {
        case .accepted:
            networkFailures = 0
            backoffUntil = nil
            return .delete

        case .rejected:
            return .delete

        case let .rateLimited(retryAfter):
            rateLimitedUntil = date.addingTimeInterval(retryAfter)
            return .keepAndStop

        case let .retryLater(after):
            networkFailures += 1
            backoffUntil = date.addingTimeInterval(after ?? backoff())
            return .keepAndStop
        }
    }

    /// The network came back: try again now instead of waiting for the backoff. The rate limit still applies.
    mutating func connectivityRestored() {
        backoffUntil = nil
    }

    // MARK: - Private Methods

    private func backoff() -> TimeInterval {
        let exponent = Double(min(networkFailures - 1, 16))

        return min(Self.maxBackoff, Self.initialBackoff * pow(2, exponent))
    }
}
