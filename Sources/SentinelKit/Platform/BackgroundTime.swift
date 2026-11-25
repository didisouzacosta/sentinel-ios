/// One request for background time: begun once, ended exactly once, on completion or on expiration, whichever
/// comes first.
@MainActor
final class BackgroundTime {

    // MARK: - Constants

    static let taskName = "SentinelKit.flush"

    // MARK: - Properties

    private let runner: any BackgroundTaskRunning

    private var identifier: BackgroundTaskID?

    // MARK: - Initializer

    init(runner: any BackgroundTaskRunning) {
        self.runner = runner
    }

    // MARK: - Methods

    func begin() {
        guard identifier == nil else {
            return
        }

        identifier = runner.begin(name: Self.taskName) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard let identifier else {
            return
        }

        self.identifier = nil
        runner.end(identifier)
    }
}
