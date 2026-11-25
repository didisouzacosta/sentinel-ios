/// Keeps the DSN only in memory, for previews and tests: nothing survives between runs.
final class InMemoryDSNStorage: DSNStorage {

    // MARK: - Properties

    private(set) var savedDSN: String?

    // MARK: - Initializer

    init(savedDSN: String? = nil) {
        self.savedDSN = savedDSN
    }

    // MARK: - DSNStorage

    func save(_ dsn: String) {
        savedDSN = dsn
    }

    func forget() {
        savedDSN = nil
    }
}
