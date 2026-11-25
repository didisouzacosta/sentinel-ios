import Foundation

/// Captures uncaught Objective-C exceptions (`NSException`), writes them to disk and then calls the handler the app
/// had before, if any.
enum ExceptionCrashHandler {

    // MARK: - Properties

    /// Kept up to date by `SentinelClient` (scope, consent); read by the handler while the app crashes.
    static let snapshots = CrashSnapshotStore()

    // MARK: - Methods

    /// Installs the handler once; later calls do nothing.
    static func install() {
        guard snapshots.markInstalled(previous: NSGetUncaughtExceptionHandler()) else {
            return
        }

        NSSetUncaughtExceptionHandler { exception in
            ExceptionCrashHandler.handle(exception)
        }
    }

    /// - Parameter store: the snapshot store; tests pass their own instead of the global one.
    static func handle(_ exception: NSException, store: CrashSnapshotStore = snapshots) {
        if let snapshot = store.current {
            CrashWriter.write(
                exceptionName: exception.name.rawValue,
                reason: exception.reason ?? "",
                addresses: exception.callStackReturnAddresses.map(\.uintValue),
                snapshot: snapshot
            )
        }

        store.previous?(exception)
    }
}
