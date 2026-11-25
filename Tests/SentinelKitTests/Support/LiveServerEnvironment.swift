import Foundation

/// Settings of the opt-in live-server tests, read from the environment (empty counts as unset).
enum LiveServerEnvironment {

    // MARK: - Constants

    /// Client key of a project on the server under test.
    static let dsn = value("SENTINEL_DSN")

    /// An API token (`wst_…`) of a member of that project, to read the event back.
    static let apiToken = value("SENTINEL_API_TOKEN")

    // MARK: - Type Methods

    private static func value(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name].flatMap { $0.isEmpty ? nil : $0 }
    }
}
