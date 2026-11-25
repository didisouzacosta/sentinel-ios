/// Asks the system for extra time to finish work after the app leaves the foreground.
@MainActor
protocol BackgroundTaskRunning: Sendable {

    // MARK: - Methods

    /// Starts a task, or returns `nil` when no time can be given (app extension, no application, time exhausted).
    /// The system calls `expiration` on the main actor when the time runs out; the task must then be ended.
    func begin(name: String, expiration: @escaping @MainActor @Sendable () -> Void) -> BackgroundTaskID?

    func end(_ identifier: BackgroundTaskID)
}
