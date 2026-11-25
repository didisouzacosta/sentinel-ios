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
    }

    // MARK: - Doubles

    private enum PaymentError: Error {
        case cardDeclined
    }
}
