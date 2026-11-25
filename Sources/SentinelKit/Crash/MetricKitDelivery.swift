import Foundation

/// One MetricKit diagnostic payload: its JSON and the time window it covers (from `MXDiagnosticPayload`'s own
/// `Date` properties, which carry the right time zone).
struct MetricKitDelivery: Sendable {

    // MARK: - Properties

    let json: Data

    let begin: Date?

    let end: Date?

    // MARK: - Initializer

    init(json: Data, begin: Date? = nil, end: Date? = nil) {
        self.json = json
        self.begin = begin
        self.end = end
    }
}
