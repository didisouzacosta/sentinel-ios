/// The SentinelKit calls the example makes, behind a protocol so previews and tests never reach the real SDK.
@MainActor
protocol SentinelService {

    // MARK: - Methods

    func start(dsn: String)

    func grantConsent()

    func revokeConsent()

    func addBreadcrumb(category: String, message: String)

    func setCustom(_ key: String, _ value: String)

    func capture(_ error: any Error)

    func capture(message: String)

    func flush() async
}
