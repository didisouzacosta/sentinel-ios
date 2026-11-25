@testable import SentinelExample

/// Records every SentinelKit call the view model makes, in order.
@MainActor
final class SpySentinelService: SentinelService {

    // MARK: - Properties

    private(set) var calls: [String] = []

    // MARK: - SentinelService

    func start(dsn: String) {
        calls.append("start \(dsn)")
    }

    func grantConsent() {
        calls.append("grantConsent")
    }

    func revokeConsent() {
        calls.append("revokeConsent")
    }

    func addBreadcrumb(category: String, message: String) {
        calls.append("breadcrumb \(category) \(message)")
    }

    func setCustom(_ key: String, _ value: String) {
        calls.append("custom \(key)=\(value)")
    }

    func capture(_ error: any Error) {
        calls.append("error \(error.localizedDescription)")
    }

    func capture(message: String) {
        calls.append("message \(message)")
    }

    func flush() {
        calls.append("flush")
    }
}
