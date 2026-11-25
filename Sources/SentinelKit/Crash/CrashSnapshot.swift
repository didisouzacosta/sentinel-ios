import Foundation

/// Everything the crash handler needs to write an event without touching actors: it runs while the app is dying.
struct CrashSnapshot: Sendable {

    // MARK: - Properties

    let location: QueueLocation

    let options: Options

    let contexts: Contexts

    let scope: Scope

    /// `false` after `revokeConsent()`: a crash then writes nothing.
    let consentAllowsCapture: Bool

    let stackTraceBuilder: StackTraceBuilder
}
