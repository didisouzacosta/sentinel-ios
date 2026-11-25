import Foundation

/// An envelope waiting on disk to be sent.
struct StoredEnvelope: Hashable, Sendable {
    let id: EventID
    let url: URL
}
