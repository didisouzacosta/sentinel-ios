import Foundation
import Testing
@testable import SentinelKit

@Suite("Delivery state")
struct DeliveryStateTests {

    // MARK: - Helpers

    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Results

    @Test("accepted and rejected envelopes are deleted")
    func deleted() {
        var state = DeliveryState()

        #expect(state.record(.accepted, at: start) == .delete)
        #expect(state.record(.rejected(statusCode: 400), at: start) == .delete)
        #expect(state.canSend(at: start))
    }

    @Test("rate limiting keeps the envelope and pauses sending for Retry-After")
    func rateLimited() {
        var state = DeliveryState()

        #expect(state.record(.rateLimited(retryAfter: 120), at: start) == .keepAndStop)
        #expect(!state.canSend(at: start.addingTimeInterval(60)))
        #expect(state.canSend(at: start.addingTimeInterval(120)))
    }

    @Test("network failures back off 30 s, then 60 s, up to one hour")
    func backoff() {
        var state = DeliveryState()

        #expect(state.record(.retryLater(after: nil), at: start) == .keepAndStop)
        #expect(!state.canSend(at: start.addingTimeInterval(29)))
        #expect(state.canSend(at: start.addingTimeInterval(30)))

        _ = state.record(.retryLater(after: nil), at: start)

        #expect(!state.canSend(at: start.addingTimeInterval(59)))

        for _ in 1...10 {
            _ = state.record(.retryLater(after: nil), at: start)
        }

        #expect(state.canSend(at: start.addingTimeInterval(3600)))
    }

    @Test("a server Retry-After overrides the backoff and success resets it")
    func retryAfterAndReset() {
        var state = DeliveryState()

        _ = state.record(.retryLater(after: 5), at: start)

        #expect(state.canSend(at: start.addingTimeInterval(5)))

        _ = state.record(.accepted, at: start)
        _ = state.record(.retryLater(after: nil), at: start)

        #expect(state.canSend(at: start.addingTimeInterval(30)))
    }

    @Test("connectivity coming back lifts the network backoff but not the rate limit")
    func connectivityRestored() {
        var network = DeliveryState()
        var rateLimited = DeliveryState()

        _ = network.record(.retryLater(after: nil), at: start)
        _ = rateLimited.record(.rateLimited(retryAfter: 600), at: start)

        network.connectivityRestored()
        rateLimited.connectivityRestored()

        #expect(network.canSend(at: start))
        #expect(!rateLimited.canSend(at: start))
    }

    @Test("reports when sending may resume, so a retry can be scheduled")
    func nextAttempt() {
        var state = DeliveryState()

        #expect(state.nextAttempt == nil)

        _ = state.record(.retryLater(after: nil), at: start)
        _ = state.record(.rateLimited(retryAfter: 600), at: start)

        #expect(state.nextAttempt == start.addingTimeInterval(600))
    }
}
