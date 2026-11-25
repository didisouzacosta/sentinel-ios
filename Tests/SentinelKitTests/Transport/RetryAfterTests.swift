import Foundation
import Testing
@testable import SentinelKit

@Suite("Retry-After")
struct RetryAfterTests {

    // MARK: - Parsing

    private let now = Date(timeIntervalSince1970: 1_445_412_400) // Wed, 21 Oct 2015 07:26:40 GMT

    @Test("reads delay seconds")
    func seconds() {
        #expect(RetryAfter.seconds(from: "120", now: now) == 120)
        #expect(RetryAfter.seconds(from: " 5 ", now: now) == 5)
    }

    @Test("reads an HTTP date relative to now")
    func httpDate() {
        #expect(RetryAfter.seconds(from: "Wed, 21 Oct 2015 07:28:00 GMT", now: now) == 80)
    }

    @Test("never returns a negative delay")
    func pastDate() {
        #expect(RetryAfter.seconds(from: "Wed, 21 Oct 2015 07:00:00 GMT", now: now) == 0)
    }

    @Test("ignores missing or invalid values", arguments: [nil, "", "soon", "-3"])
    func invalid(value: String?) {
        #expect(RetryAfter.seconds(from: value, now: now) == nil)
    }
}
