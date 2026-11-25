import Foundation
@testable import SentinelKit

/// Deterministic values shared by the encoding and envelope tests.
enum EventFixtures {

    // MARK: - Values

    static let eventID = EventID(rawValue: "0123456789abcdef0123456789abcdef")

    /// 2025-11-24T16:00:00.500Z
    static let timestamp = Date(timeIntervalSince1970: 1_764_000_000.5)

    static let sdk = SDKInfo(name: "sentinel.cocoa", version: "0.1.0")

    // MARK: - Events

    static var message: Event {
        Event(
            eventID: eventID,
            timestamp: timestamp,
            level: .info,
            message: "Checkout opened",
            sdk: sdk
        )
    }

    static var handledError: Event {
        var event = Event(eventID: eventID, timestamp: timestamp, level: .error, sdk: sdk)
        event.release = "com.example.shop@3.2.0+412"
        event.environment = "production"
        event.tags = ["screen": "checkout"]
        event.breadcrumbs = [
            Breadcrumb(timestamp: timestamp, category: "ui", message: "Tapped Pay", level: .info),
        ]
        event.exception = ExceptionList(
            values: [
                ExceptionValue(
                    type: "PaymentError",
                    value: "Card declined",
                    mechanism: Mechanism(type: "generic", handled: true),
                    stacktrace: Stacktrace(
                        frames: [
                            StackFrame(
                                function: "main",
                                package: "/usr/lib/dyld",
                                instructionAddress: "0x0000000100001000",
                                inApp: false
                            ),
                            StackFrame(
                                function: "CheckoutViewModel.pay()",
                                filename: "CheckoutViewModel.swift",
                                lineNumber: 42,
                                package: "Shop",
                                instructionAddress: "0x0000000104a2b3c4",
                                imageAddress: "0x0000000104000000",
                                inApp: true
                            ),
                        ]
                    )
                ),
            ]
        )
        return event
    }
}
