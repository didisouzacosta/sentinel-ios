import Foundation

/// Something that happened before an event (a tap, a request, a log line).
struct Breadcrumb: Hashable, Sendable, Encodable {

    // MARK: - Properties

    var timestamp: Date

    var category: String?

    var message: String?

    var level: Level?

    // MARK: - Initializer

    init(timestamp: Date = Date(), category: String? = nil, message: String? = nil, level: Level? = nil) {
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.level = level
    }
}
