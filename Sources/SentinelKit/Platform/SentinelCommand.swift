import Foundation

/// A call to the public API, queued so calls are handled in the order they were made.
enum SentinelCommand: Sendable {

    // MARK: - Commands

    case start(dsn: String, options: Options)
    case captureError(any Error, addresses: [UInt])
    case captureMessage(String, Level)
    case breadcrumb(Breadcrumb)
    case custom(String, String?)
    case grantConsent
    case revokeConsent
    case connectivityRestored
    /// MetricKit diagnostics (JSON) with crashes of earlier sessions.
    case metricKitPayloads([MetricKitDelivery])
    /// Starts sending without waiting (launch, app lifecycle).
    case triggerFlush
    /// Resumes once the queue was sent (or delivery had to stop); does not hold the queue meanwhile.
    case flush(CheckedContinuation<Void, Never>)
    /// Resumes once every earlier command was handled.
    case barrier(CheckedContinuation<Void, Never>)
}
