import Foundation

/// Identifier of an event: 32 lowercase hexadecimal characters, the format the Sentinel server expects.
struct EventID: RawRepresentable, Hashable, Sendable, Encodable {

    // MARK: - Properties

    let rawValue: String

    // MARK: - Initializers

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a random identifier.
    init() {
        rawValue = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    // MARK: - Encodable

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(rawValue)
    }
}
