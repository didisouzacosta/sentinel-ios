import Foundation

/// Saves the consent decision in `UserDefaults`. It is a preference, not a secret.
struct UserDefaultsConsentStore: ConsentStore {

    // MARK: - Constants

    static let key = "SentinelKit.consent"

    // MARK: - Properties

    /// `nil` uses `UserDefaults.standard`; tests pass their own suite.
    private let suiteName: String?

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: - Initializer

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    // MARK: - ConsentStore

    func load() -> ConsentState {
        defaults.string(forKey: Self.key).flatMap(ConsentState.init(rawValue:)) ?? .unknown
    }

    func save(_ state: ConsentState) {
        defaults.set(state.rawValue, forKey: Self.key)
    }
}
