import Foundation

/// One item of an envelope: its header fields and its raw payload.
struct EnvelopeItem: Hashable, Sendable {

    // MARK: - Properties

    let kind: Kind

    let payload: Data

    let contentType: String?

    let filename: String?

    // MARK: - Header

    /// Item header line. `length` is the payload size in bytes.
    var header: Header {
        Header(type: kind.rawValue, length: payload.count, contentType: contentType, filename: filename)
    }

    // MARK: - Types

    enum Kind: String, Sendable {
        case event
        case attachment
    }

    struct Header: Encodable {

        // MARK: - Fields

        let type: String
        let length: Int
        let contentType: String?
        let filename: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case length
            case contentType = "content_type"
            case filename
        }
    }
}
