import Foundation

/// The error the example captures, with a readable message for the issue title.
enum CheckoutError: LocalizedError, Sendable {
    case cardDeclined

    var errorDescription: String? {
        switch self {
        case .cardDeclined:
            "Card declined by the bank"
        }
    }
}
