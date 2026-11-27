import Foundation
import Testing
@testable import SentinelKit

@Suite("Event encoding")
struct EventEncodingTests {

    // MARK: - Helpers

    private func json(_ event: Event) throws -> [String: Any] {
        let data = try SentinelJSON.encoder.encode(event)

        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Contract with the Sentinel server

    @Test("sends message as a plain string, not an object")
    func messageIsString() throws {
        let object = try json(EventFixtures.message)

        #expect(object["message"] as? String == "Checkout opened")
    }

    @Test("sends the timestamp as ISO-8601 with milliseconds in UTC")
    func timestampIsISO8601() throws {
        let object = try json(EventFixtures.message)

        #expect(object["timestamp"] as? String == "2025-11-24T16:00:00.500Z")
    }

    @Test("sends a 32-character hex event id, platform cocoa and the level name")
    func identityFields() throws {
        let object = try json(EventFixtures.message)

        #expect(object["event_id"] as? String == "0123456789abcdef0123456789abcdef")
        #expect(object["platform"] as? String == "cocoa")
        #expect(object["level"] as? String == "info")
    }

    @Test("omits fields that were not set")
    func omitsNil() throws {
        let object = try json(EventFixtures.message)

        #expect(object["exception"] == nil)
        #expect(object["release"] == nil)
        #expect(object["breadcrumbs"] == nil)
    }

    @Test("never sends a user field: identifying data only travels as explicit custom parameters")
    func noUserField() throws {
        let object = try json(EventFixtures.handledError)

        #expect(object["user"] == nil)
        #expect((object["tags"] as? [String: String]) == ["screen": "checkout"])
    }

    @Test("uses Sentry's snake_case keys for frames")
    func frameKeys() throws {
        let object = try json(EventFixtures.handledError)
        let exception = try #require(object["exception"] as? [String: Any])
        let values = try #require(exception["values"] as? [[String: Any]])
        let stacktrace = try #require(values.first?["stacktrace"] as? [String: Any])
        let frames = try #require(stacktrace["frames"] as? [[String: Any]])
        let appFrame = try #require(frames.last)

        #expect(appFrame["function"] as? String == "CheckoutViewModel.pay()")
        #expect(appFrame["lineno"] as? Int == 42)
        #expect(appFrame["in_app"] as? Bool == true)
        #expect(appFrame["instruction_addr"] as? String == "0x0000000104a2b3c4")
        #expect(appFrame["image_addr"] as? String == "0x0000000104000000")
    }

    @Test("sends breadcrumbs as a plain array with ISO timestamps")
    func breadcrumbsArray() throws {
        let object = try json(EventFixtures.handledError)
        let breadcrumbs = try #require(object["breadcrumbs"] as? [[String: Any]])

        #expect(breadcrumbs.first?["timestamp"] as? String == "2025-11-24T16:00:00.500Z")
        #expect(breadcrumbs.first?["category"] as? String == "ui")
    }

    @Test("sends image_size as a number and arch when known, and omits both when unknown")
    func debugImageKeys() throws {
        var event = EventFixtures.message
        event.debugMeta = DebugMeta(
            images: [
                DebugImage(
                    debugID: "a1b2c3d4-0000-1111-2222-333344445555",
                    imageAddress: "0x0000000100000000",
                    codeFile: "Shop.app/Shop",
                    imageSize: 16384,
                    arch: "arm64"
                ),
                DebugImage(
                    debugID: "a1b2c3d4-0000-1111-2222-333344445555",
                    imageAddress: "0x0000000100000000",
                    codeFile: "Shop"
                ),
            ]
        )

        let object = try json(event)
        let images = try #require((object["debug_meta"] as? [String: Any])?["images"] as? [[String: Any]])
        let known = try #require(images.first)
        let unknown = try #require(images.last)

        #expect(known["type"] as? String == "macho")
        #expect(known["debug_id"] as? String == "a1b2c3d4-0000-1111-2222-333344445555")
        #expect(known["image_addr"] as? String == "0x0000000100000000")
        #expect(known["code_file"] as? String == "Shop.app/Shop")
        #expect((known["image_size"] as? NSNumber)?.int64Value == 16384)
        #expect(known["image_size"] is NSNumber)
        #expect(!(known["image_size"] is String))
        #expect(known["arch"] as? String == "arm64")
        #expect(unknown["image_size"] == nil)
        #expect(unknown["arch"] == nil)
        #expect(unknown["code_file"] as? String == "Shop")
    }

    // MARK: - Event id

    @Test("generates random ids as 32 lowercase hex characters")
    func randomEventID() {
        let first = EventID()
        let second = EventID()

        #expect(first.rawValue.count == 32)
        #expect(first.rawValue.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        #expect(first != second)
    }
}
