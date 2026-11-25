import Foundation

/// Holds the latest `CrashSnapshot` for the uncaught-exception handler.
///
/// Bridge: `NSSetUncaughtExceptionHandler` takes a C function that cannot capture context and runs synchronously on
/// the crashing thread, so it cannot await an actor. This box is the only shared mutable state in the SDK. Invariant
/// that makes it safe: every read and write of `snapshot` and `previousHandler` happens inside `lock`, and the values
/// stored are immutable `Sendable` values (or a C function pointer), so nothing escapes the lock mutably.
final class CrashSnapshotStore: @unchecked Sendable {

    // MARK: - Properties

    private let lock = NSLock()

    private var snapshot: CrashSnapshot?

    private var previousHandler: NSUncaughtExceptionHandler?

    private var isInstalled = false

    var current: CrashSnapshot? {
        locked { snapshot }
    }

    var previous: NSUncaughtExceptionHandler? {
        locked { previousHandler }
    }

    // MARK: - Methods

    func update(_ snapshot: CrashSnapshot) {
        locked { self.snapshot = snapshot }
    }

    /// Records the handler that was installed before ours, once. `false` if ours was already installed.
    func markInstalled(previous: NSUncaughtExceptionHandler?) -> Bool {
        locked {
            guard !isInstalled else {
                return false
            }

            isInstalled = true
            previousHandler = previous
            return true
        }
    }

    // MARK: - Private Methods

    /// `NSLock.withLock` needs iOS 16, so lock and unlock by hand.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()

        defer {
            lock.unlock()
        }

        return body()
    }
}
