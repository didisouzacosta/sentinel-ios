import Foundation
@testable import SentinelKit

/// A `UserDefaultsConsentStore` on its own suite, so tests never touch the real defaults.
struct TestConsentStore: ConsentStore {

    // MARK: - Properties

    let suiteName = "SentinelKitTests.\(UUID().uuidString)"

    // MARK: - Initializer

    init(_ initial: ConsentState = .unknown) {
        if initial != .unknown {
            save(initial)
        }
    }

    // MARK: - ConsentStore

    func load() -> ConsentState {
        UserDefaultsConsentStore(suiteName: suiteName).load()
    }

    func save(_ state: ConsentState) {
        UserDefaultsConsentStore(suiteName: suiteName).save(state)
    }

    // MARK: - Methods

    func removeSuite() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}
