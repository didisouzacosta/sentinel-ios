import Foundation
import Testing
@testable import SentinelKit

@Suite("Envelope encoder")
struct EnvelopeEncoderTests {

    // MARK: - Helpers

    private let encoder = EnvelopeEncoder()

    private func lines(_ data: Data) throws -> [String] {
        let text = try #require(String(data: data, encoding: .utf8))

        return text.components(separatedBy: "\n")
    }

    private func object(_ line: String) throws -> [String: Any] {
        let data = Data(line.utf8)

        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Format

    @Test("writes the envelope header, then each item header and payload on its own line")
    func layout() throws {
        let envelope = try Envelope(event: EventFixtures.message, sentAt: EventFixtures.timestamp)
        let parts = try lines(encoder.encode(envelope))

        #expect(parts.count == 3)

        let header = try object(parts[0])

        #expect(header["event_id"] as? String == EventFixtures.eventID.rawValue)
        #expect(header["sent_at"] as? String == "2025-11-24T16:00:00.500Z")

        let itemHeader = try object(parts[1])

        #expect(itemHeader["type"] as? String == "event")
        #expect(try object(parts[2])["message"] as? String == "Checkout opened")
    }

    @Test("declares the item length in bytes, not characters")
    func lengthInBytes() throws {
        var event = EventFixtures.message
        event.message = "Ação recusada ✋"

        let envelope = try Envelope(event: event, sentAt: EventFixtures.timestamp)
        let parts = try lines(encoder.encode(envelope))
        let declared = try #require(try object(parts[1])["length"] as? Int)

        #expect(declared == Data(parts[2].utf8).count)
        #expect(declared > parts[2].count)
    }

    @Test("adds attachments after the event with content type and filename")
    func attachment() throws {
        let log = Data("line 1\nline 2".utf8)
        let envelope = try Envelope(
            event: EventFixtures.message,
            attachments: [Attachment(filename: "app.log", contentType: "text/plain", data: log)],
            sentAt: EventFixtures.timestamp
        )
        let data = try encoder.encode(envelope)
        let text = try #require(String(data: data, encoding: .utf8))

        let expectedTail = "{\"content_type\":\"text/plain\",\"filename\":\"app.log\","
            + "\"length\":13,\"type\":\"attachment\"}\nline 1\nline 2"

        #expect(text.hasSuffix(expectedTail))
    }

    // MARK: - Contract fixture

    /// The same file is accepted by the Sentinel server's own test suite. Regenerate it only on purpose:
    /// `RECORD_FIXTURES=1 swift test --filter contractFixture`, then validate it against the server again.
    @Test("matches the contract fixture byte for byte")
    func contractFixture() throws {
        let envelope = try Envelope(event: EventFixtures.handledError, sentAt: EventFixtures.timestamp)
        let actual = try encoder.encode(envelope)

        if ProcessInfo.processInfo.environment["RECORD_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/handled-error.envelope")

            try actual.write(to: source)
            // The bundle still holds the previous copy until the next build, so stop here.
            return
        }

        let url = try #require(
            Bundle.module.url(forResource: "handled-error", withExtension: "envelope", subdirectory: "Fixtures")
        )
        let expected = try Data(contentsOf: url)

        #expect(String(bytes: actual, encoding: .utf8) == String(bytes: expected, encoding: .utf8))
    }
}
