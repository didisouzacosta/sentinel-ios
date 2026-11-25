import Foundation
import Testing
@testable import SentinelKit

@Suite("Error descriptor")
struct ErrorDescriptorTests {

    // MARK: - Description

    @Test("uses the type name and the case of a Swift error")
    func swiftEnum() {
        let description = ErrorDescriptor(PaymentError.cardDeclined)

        #expect(description.type == "PaymentError")
        #expect(description.value == "cardDeclined")
    }

    @Test("prefers the errorDescription of a LocalizedError")
    func localizedError() {
        let description = ErrorDescriptor(ReadableError())

        #expect(description.type == "ReadableError")
        #expect(description.value == "Card declined by the bank")
    }

    @Test("uses the domain and code of an NSError")
    func nsError() {
        let error = NSError(domain: "ShopErrorDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Out of stock"])
        let description = ErrorDescriptor(error)

        #expect(description.type == "ShopErrorDomain")
        #expect(description.value == "Code 42: Out of stock")
    }

    // MARK: - Doubles

    private enum PaymentError: Error {
        case cardDeclined
    }

    private struct ReadableError: LocalizedError {
        var errorDescription: String? {
            "Card declined by the bank"
        }
    }
}
