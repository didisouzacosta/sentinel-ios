import Foundation

/// What the SDK sends to Sentinel: one event and its attachments, in the Sentry envelope format the server
/// already understands. Only the format is shared with Sentry; nothing else is.
struct Envelope: Sendable {

    // MARK: - Properties

    let header: Header

    let items: [EnvelopeItem]

    var eventID: EventID {
        header.eventID
    }

    // MARK: - Initializer

    /// Builds the envelope for `event`, encoding the event JSON once.
    init(event: Event, attachments: [Attachment] = [], sentAt: Date = Date()) throws {
        let eventItem = try EnvelopeItem(
            kind: .event,
            payload: SentinelJSON.encoder.encode(event),
            contentType: nil,
            filename: nil
        )
        let attachmentItems = attachments.map { attachment in
            EnvelopeItem(
                kind: .attachment,
                payload: attachment.data,
                contentType: attachment.contentType,
                filename: attachment.filename
            )
        }

        header = Header(eventID: event.eventID, sentAt: sentAt, sdk: event.sdk)
        items = [eventItem] + attachmentItems
    }

    // MARK: - Types

    struct Header: Encodable {
        let eventID: EventID
        let sentAt: Date
        let sdk: SDKInfo

        private enum CodingKeys: String, CodingKey {
            case eventID = "event_id"
            case sentAt = "sent_at"
            case sdk
        }
    }
}
