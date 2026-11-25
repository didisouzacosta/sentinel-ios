import Foundation

/// Where the offline queue lives and how many envelopes it keeps.
struct QueueLocation: Hashable, Sendable {
    let directory: URL
    let capacity: Int
}
