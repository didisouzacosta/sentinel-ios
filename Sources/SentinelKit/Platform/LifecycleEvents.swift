import Foundation
#if canImport(UIKit) && os(iOS)
    import UIKit
#endif

/// The app-lifecycle notifications that send the queue, and where background time comes from.
struct LifecycleEvents: Sendable {

    // MARK: - Type Properties

    #if canImport(UIKit) && os(iOS)
        static var live: LifecycleEvents {
            LifecycleEvents(
                center: .default,
                didEnterBackground: UIApplication.didEnterBackgroundNotification,
                didBecomeActive: UIApplication.didBecomeActiveNotification,
                backgroundTasks: UIKitBackgroundTasks()
            )
        }
    #endif

    // MARK: - Properties

    let center: NotificationCenter

    /// Sends the queue with extra background time.
    let didEnterBackground: Notification.Name

    /// Starts sending without waiting.
    let didBecomeActive: Notification.Name

    let backgroundTasks: any BackgroundTaskRunning
}
