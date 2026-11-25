/// Identifier of a background task, independent of UIKit so the logic around it runs on every platform.
struct BackgroundTaskID: Hashable, Sendable {
    let rawValue: Int
}
