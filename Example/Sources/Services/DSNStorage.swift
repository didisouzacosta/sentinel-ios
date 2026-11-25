/// Where the DSN typed in the app is kept, so the next launch (for example, after a crash) starts the SDK at once.
@MainActor
protocol DSNStorage {

    // MARK: - Properties

    var savedDSN: String? { get }

    // MARK: - Methods

    func save(_ dsn: String)

    func forget()
}
