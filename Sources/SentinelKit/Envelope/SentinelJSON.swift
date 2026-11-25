import Foundation

/// JSON settings shared by events and envelope headers: sorted keys (stable output) and ISO-8601 dates with
/// milliseconds in UTC, e.g. `2025-11-24T16:00:00.500Z`.
enum SentinelJSON {

    // MARK: - Encoder

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()

            try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }

        return encoder
    }
}
