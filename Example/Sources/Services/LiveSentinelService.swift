import SentinelKit

/// Forwards to the SentinelKit facade: this is the code an app writes.
struct LiveSentinelService: SentinelService {

    // MARK: - SentinelService

    func start(dsn: String) {
        Sentinel.start(dsn: dsn) { options in
            options.environment = "example"
        }
    }

    func grantConsent() {
        Sentinel.grantConsent()
    }

    func revokeConsent() {
        Sentinel.revokeConsent()
    }

    func addBreadcrumb(category: String, message: String) {
        Sentinel.addBreadcrumb(category: category, message: message)
    }

    func setCustom(_ key: String, _ value: String) {
        Sentinel.setCustom(key, value)
    }

    func capture(_ error: any Error) {
        Sentinel.capture(error)
    }

    func capture(message: String) {
        Sentinel.capture(message: message, level: .info)
    }

    func flush() async {
        await Sentinel.flush()
    }
}
