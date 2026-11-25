import Foundation

/// One line of the activity list: what the user asked the SDK to do.
struct ActivityEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    let date: Date
    let text: String
}
