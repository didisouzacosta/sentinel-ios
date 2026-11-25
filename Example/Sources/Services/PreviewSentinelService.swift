/// Does nothing: previews never start the SDK, install crash handlers or touch the network.
struct PreviewSentinelService: SentinelService {

    // MARK: - SentinelService

    func start(dsn: String) {}

    func grantConsent() {}

    func revokeConsent() {}

    func addBreadcrumb(category: String, message: String) {}

    func setCustom(_ key: String, _ value: String) {}

    func capture(_ error: any Error) {}

    func capture(message: String) {}

    func flush() {}
}
