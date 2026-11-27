import Foundation
import Testing
@testable import SentinelKit

@Suite("Event builder")
struct EventBuilderTests {

    // MARK: - Helpers

    private var builder: EventBuilder {
        var options = Options()
        options.environment = "production"
        options.release = "com.example.shop@3.2.0+412"
        options.dist = "412"

        let contexts = ContextProvider.contexts(
            app: AppInfo(identifier: "com.example.shop", name: "Shop", version: "3.2.0", build: "412")
        )

        return EventBuilder(
            options: options,
            contexts: contexts,
            stackTraceBuilder: StackTraceBuilder(isInApp: { $0.contains(".xctest") })
        )
    }

    private var scope: Scope {
        var scope = Scope()
        scope.add(Breadcrumb(category: "ui", message: "Tapped Pay"))
        scope.setCustom("plan", "pro")
        return scope
    }

    // MARK: - Errors

    @Test("turns an error into a handled exception with frames, scope and context")
    func errorEvent() throws {
        let date = EventFixtures.timestamp
        let event = builder.event(
            for: PaymentError.cardDeclined,
            addresses: StackTraceBuilder.currentAddresses(),
            scope: scope,
            at: date
        )
        let exception = try #require(event.exception?.values.first)
        let frames = try #require(exception.stacktrace?.frames)
        let images = try #require(event.debugMeta?.images)
        let imageAddresses = Set(images.map(\.imageAddress))

        #expect(event.level == .error)
        #expect(event.timestamp == date)
        #expect(exception.type == "PaymentError")
        #expect(exception.value == "cardDeclined")
        #expect(exception.mechanism == Mechanism(type: "generic", handled: true))
        #expect((exception.stacktrace?.frames.count ?? 0) > 0)
        #expect(event.breadcrumbs?.map(\.message) == ["Tapped Pay"])
        #expect(event.tags == ["plan": "pro"])
        #expect(event.release == "com.example.shop@3.2.0+412")
        #expect(event.environment == "production")
        #expect(event.dist == "412")
        #expect(event.contexts?.app?.identifier == "com.example.shop")
        #expect(!images.isEmpty)
        #expect(frames.allSatisfy { $0.imageAddress.map(imageAddresses.contains) == true })
    }

    @Test("encodes debug_meta.images with the keys the server needs to match dSYMs")
    func errorEventJSON() throws {
        let event = builder.event(
            for: PaymentError.cardDeclined,
            addresses: StackTraceBuilder.currentAddresses(),
            scope: Scope(),
            at: Date()
        )
        let data = try SentinelJSON.encoder.encode(event)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try #require((object["debug_meta"] as? [String: Any])?["images"] as? [[String: Any]])
        let image = try #require(images.first)
        let exception = try #require((object["exception"] as? [String: Any])?["values"] as? [[String: Any]])
        let frames = try #require((exception.first?["stacktrace"] as? [String: Any])?["frames"] as? [[String: Any]])
        let frameImages = Set(frames.compactMap { $0["image_addr"] as? String })
        let imageAddresses = Set(images.compactMap { $0["image_addr"] as? String })
        let imageAddress = try #require(image["image_addr"] as? String)

        #expect(image["type"] as? String == "macho")
        #expect(MachOFixtures.isDebugID(image["debug_id"] as? String))
        #expect(imageAddress.hasPrefix("0x"))
        #expect(imageAddress.count == 18)
        #expect(((image["image_size"] as? NSNumber)?.uint64Value ?? 0) > 0)
        #expect((image["arch"] as? String)?.isEmpty == false)
        #expect((image["code_file"] as? String)?.isEmpty == false)
        #expect(frameImages.isSubset(of: imageAddresses))
    }

    @Test("adds debug_meta to an uncaught exception's event too")
    func exceptionEventDebugMeta() {
        let event = builder.event(
            exceptionName: "NSRangeException",
            reason: "index 5 beyond bounds [0 .. 2]",
            addresses: StackTraceBuilder.currentAddresses(),
            scope: Scope(),
            at: Date()
        )

        #expect(event.debugMeta?.images.isEmpty == false)
    }

    @Test("sends neither stacktrace nor debug_meta without frames")
    func noFrames() {
        let event = builder.event(for: PaymentError.cardDeclined, addresses: [], scope: Scope(), at: Date())

        #expect(event.exception?.values.first?.stacktrace == nil)
        #expect(event.debugMeta == nil)
    }

    // MARK: - Messages

    @Test("turns a message into an event without exception")
    func messageEvent() {
        let event = builder.event(message: "Checkout opened", level: .info, scope: Scope(), at: Date())

        #expect(event.message == "Checkout opened")
        #expect(event.level == .info)
        #expect(event.exception == nil)
        #expect(event.breadcrumbs == nil)
        #expect(event.tags == nil)
        #expect(event.debugMeta == nil)
    }

    // MARK: - Doubles

    private enum PaymentError: Error {
        case cardDeclined
    }
}
