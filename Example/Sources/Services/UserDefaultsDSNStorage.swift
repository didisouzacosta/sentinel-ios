import Foundation

/// Keeps the DSN in the app's `UserDefaults`.
struct UserDefaultsDSNStorage: DSNStorage {

    // MARK: - Constants

    static let key = "SentinelExample.dsn"

    // MARK: - Properties

    var savedDSN: String? {
        UserDefaults.standard.string(forKey: Self.key).flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - DSNStorage

    func save(_ dsn: String) {
        UserDefaults.standard.set(dsn, forKey: Self.key)
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
