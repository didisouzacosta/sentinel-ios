/// Stands in for the hub in lifecycle tests: records flush requests and holds each flush until `open()`.
actor FlushProbe {

    // MARK: - Properties

    private(set) var flushes = 0

    private(set) var triggers = 0

    private var isOpen = false

    private var held: [CheckedContinuation<Void, Never>] = []

    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Methods

    func flush() async {
        flushes += 1
        notify()

        if !isOpen {
            await withCheckedContinuation { held.append($0) }
        }
    }

    func trigger() {
        triggers += 1
        notify()
    }

    /// Lets every held flush finish, and later ones finish at once.
    func open() {
        isOpen = true
        held.forEach { $0.resume() }
        held.removeAll()
    }

    /// Waits until at least `flushes` flushes and `triggers` triggers arrived.
    func wait(flushes: Int = 0, triggers: Int = 0) async {
        while self.flushes < flushes || self.triggers < triggers {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    // MARK: - Private Methods

    private func notify() {
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
