import Foundation

/// A file sent with an event, such as a log. The server keeps attachments only when the envelope has one event.
struct Attachment: Hashable, Sendable {

    // MARK: - Properties

    var filename: String

    var contentType: String

    var data: Data

    // MARK: - Initializer

    init(filename: String, contentType: String = "application/octet-stream", data: Data) {
        self.filename = filename
        self.contentType = contentType
        self.data = data
    }
}
