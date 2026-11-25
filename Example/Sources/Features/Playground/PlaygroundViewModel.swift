import Foundation
import Observation

/// Drives the playground: each action calls one SentinelKit API and is listed in the activity.
@MainActor
@Observable
final class PlaygroundViewModel {

    // MARK: - Properties

    var dsn: String

    private(set) var isStarted: Bool

    /// Stored, not read from the storage, so the view updates when it changes.
    private(set) var hasSavedDSN: Bool

    private(set) var activity: [ActivityEntry] = []

    private let service: any SentinelService

    private let storage: any DSNStorage

    var canStart: Bool {
        !isStarted && !trimmedDSN.isEmpty
    }

    private var trimmedDSN: String {
        dsn.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Initializer

    /// With a saved DSN the app already started the SDK at launch, so the playground opens started.
    init(service: any SentinelService, storage: any DSNStorage) {
        self.service = service
        self.storage = storage
        dsn = storage.savedDSN ?? ""
        isStarted = storage.savedDSN != nil
        hasSavedDSN = storage.savedDSN != nil
    }

    // MARK: - Setup

    /// Saves the DSN and starts the SDK; later launches start it right away.
    func start() {
        guard canStart else {
            return
        }

        let dsn = trimmedDSN

        self.dsn = dsn
        storage.save(dsn)
        hasSavedDSN = true
        service.start(dsn: dsn)
        isStarted = true
        log("Start requested (an invalid DSN is reported in the Xcode console)")
    }

    /// The SDK keeps running until the app closes; the next launch asks for a DSN again.
    func forgetDSN() {
        guard hasSavedDSN else {
            return
        }

        storage.forget()
        hasSavedDSN = false
        log("DSN forgotten: close and reopen the app to enter another one")
    }

    // MARK: - Consent

    func grantConsent() {
        service.grantConsent()
        log("Consent granted: waiting events are sent")
    }

    func revokeConsent() {
        service.revokeConsent()
        log("Consent revoked: queue cleared, capture stopped")
    }

    // MARK: - Capture

    func addBreadcrumb() {
        service.addBreadcrumb(category: "ui", message: "Tapped Pay")
        log("Breadcrumb added")
    }

    func setPlan() {
        service.setCustom("plan", "pro")
        log("Custom parameter plan = pro")
    }

    func captureError() {
        service.capture(CheckoutError.cardDeclined)
        log("Error captured")
    }

    func captureMessage() {
        service.capture(message: "Hello from the SentinelKit example")
        log("Message captured")
    }

    func requestFlush() {
        Task {
            await flush()
        }
    }

    func flush() async {
        await service.flush()
        log("Flush finished (events without consent or network stay on the device)")
    }

    // MARK: - Crashes

    /// Raises an uncaught Objective-C exception (`NSRangeException`): the handler writes it, the next launch sends it.
    func crashWithException() {
        let empty = NSArray()

        _ = empty.object(at: 5)
    }

    /// A Swift runtime trap: reported by MetricKit on a later launch, on a real device only.
    func crashWithFatalError() {
        fatalError("SentinelKit example: deliberate crash")
    }

    // MARK: - Private Methods

    private func log(_ text: String) {
        activity.insert(ActivityEntry(date: Date(), text: text), at: 0)
    }
}
