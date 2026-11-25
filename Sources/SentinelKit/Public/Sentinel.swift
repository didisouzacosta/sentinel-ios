import Foundation

/// SentinelKit's whole public API.
///
/// ```swift
/// Sentinel.start(dsn: "https://<key>@sentinel.adrianosouzacosta.com.br/<id>")
/// Sentinel.grantConsent()            // after informing the user (default policy)
/// Sentinel.capture(error)
/// ```
///
/// Every call returns immediately; the work happens in the background, in the order of the calls.
public enum Sentinel {

    // MARK: - Properties

    private static let hub = SentinelHub.live

    // MARK: - Setup

    /// Starts the SDK once, at launch. An invalid DSN leaves it off (see the system log).
    public static func start(dsn: String, configure: (inout Options) -> Void = { _ in }) {
        var options = Options()

        configure(&options)

        if options.release == nil {
            options.release = AppInfo(bundle: .main).release
        }

        hub.send(.start(dsn: dsn, options: options))
    }

    // MARK: - Capture

    /// Sends an error with the stack of the place that called it.
    public static func capture(_ error: any Error) {
        hub.send(.captureError(error, addresses: StackTraceBuilder.currentAddresses()))
    }

    public static func capture(message: String, level: Level = .info) {
        hub.send(.captureMessage(message, level))
    }

    /// Records something that happened, attached to the next events (the last 50 are kept). No personal data.
    public static func addBreadcrumb(category: String? = nil, message: String, level: Level = .info) {
        hub.send(.breadcrumb(Breadcrumb(category: category, message: message, level: level)))
    }

    /// Custom parameter sent with every event as a tag; `nil` removes it. Prefer internal ids to e-mails or names.
    public static func setCustom(_ key: String, _ value: String?) {
        hub.send(.custom(key, value))
    }

    // MARK: - Consent

    /// The user was informed and agreed: events waiting on the device are sent. Remembered between launches.
    public static func grantConsent() {
        hub.send(.grantConsent)
    }

    /// Deletes everything waiting on the device and stops capturing. Remembered between launches.
    public static func revokeConsent() {
        hub.send(.revokeConsent)
    }

    // MARK: - Delivery

    /// Waits until the queue was sent (or delivery had to stop). Not needed in normal use.
    public static func flush() async {
        await withCheckedContinuation { continuation in
            hub.send(.flush(continuation))
        }
    }
}
