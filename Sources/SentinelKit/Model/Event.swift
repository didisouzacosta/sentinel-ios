import Foundation

/// An error, crash or message sent to Sentinel.
///
/// Encodes to the event JSON the Sentinel server accepts: `message` is a plain string, `timestamp`
/// is ISO-8601 and breadcrumbs are a plain array.
///
/// Privacy: there is no user field. Nothing identifying a person is collected automatically; an app that needs
/// it passes it on purpose as a custom parameter (`tags`).
struct Event: Sendable, Encodable {

    // MARK: - Properties

    let eventID: EventID

    let platform = "cocoa"

    var timestamp: Date

    var level: Level

    var message: String?

    var exception: ExceptionList?

    var release: String?

    var environment: String?

    var dist: String?

    var tags: [String: String]?

    var breadcrumbs: [Breadcrumb]?

    var fingerprint: [String]?

    var sdk: SDKInfo

    // MARK: - Initializer

    init(
        eventID: EventID = EventID(),
        timestamp: Date = Date(),
        level: Level = .error,
        message: String? = nil,
        sdk: SDKInfo = .current
    ) {
        self.eventID = eventID
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.sdk = sdk
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {

        // MARK: - Keys

        case eventID = "event_id"
        case platform
        case timestamp
        case level
        case message
        case exception
        case release
        case environment
        case dist
        case tags
        case breadcrumbs
        case fingerprint
        case sdk
    }
}
