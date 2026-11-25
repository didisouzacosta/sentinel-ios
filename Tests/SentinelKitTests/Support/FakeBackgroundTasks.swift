@testable import SentinelKit

/// Records begin and end calls, can refuse time and can make the time run out.
@MainActor
final class FakeBackgroundTasks: BackgroundTaskRunning {

    // MARK: - Properties

    private(set) var log: [String] = []

    private let grantsTime: Bool

    private var expiration: (@MainActor @Sendable () -> Void)?

    private var nextID = 0

    private var endWaiters: [CheckedContinuation<Void, Never>] = []

    var endCount: Int {
        log.filter { $0.hasPrefix("end") }.count
    }

    // MARK: - Initializer

    nonisolated init(grantsTime: Bool = true) {
        self.grantsTime = grantsTime
    }

    // MARK: - Methods

    /// Calls the expiration handler, as the system does when the time runs out.
    func expire() {
        expiration?()
    }

    /// Waits until at least `count` tasks were ended.
    func waitForEnds(_ count: Int) async {
        while endCount < count {
            await withCheckedContinuation { endWaiters.append($0) }
        }
    }

    // MARK: - BackgroundTaskRunning

    func begin(name: String, expiration: @escaping @MainActor @Sendable () -> Void) -> BackgroundTaskID? {
        guard grantsTime else {
            log.append("refused \(name)")
            return nil
        }

        nextID += 1
        self.expiration = expiration
        log.append("begin \(name) #\(nextID)")
        return BackgroundTaskID(rawValue: nextID)
    }

    func end(_ identifier: BackgroundTaskID) {
        log.append("end #\(identifier.rawValue)")
        endWaiters.forEach { $0.resume() }
        endWaiters.removeAll()
    }
}
