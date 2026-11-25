import Foundation

/// Sends the queue when the app goes to the background (holding background time until the send ends) and when it
/// becomes active again.
enum LifecycleObserver {

    // MARK: - Type Methods

    /// Registers the observers for the life of the process: the app uses the default center, which is never released.
    /// The blocks capture only the background-task runner, never the center.
    ///
    /// The background task begins synchronously inside the notification, before the system can suspend the app, and
    /// each notification gets its own task, so a slow earlier send never delays the next request for time.
    static func observe(
        _ events: LifecycleEvents,
        flush: @escaping @Sendable () async -> Void,
        triggerFlush: @escaping @Sendable () -> Void
    ) {
        let backgroundTasks = events.backgroundTasks

        _ = events.center.addObserver(forName: events.didEnterBackground, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                let time = BackgroundTime(runner: backgroundTasks)

                time.begin()
                Task { @MainActor in
                    await flush()
                    time.end()
                }
            }
        }

        _ = events.center.addObserver(forName: events.didBecomeActive, object: nil, queue: .main) { _ in
            triggerFlush()
        }
    }
}
