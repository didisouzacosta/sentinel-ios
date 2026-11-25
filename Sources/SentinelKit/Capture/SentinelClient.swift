import Foundation

/// The SDK engine. Captures go to the offline queue first; the queue is sent only when consent allows it and the
/// delivery state says the server is reachable.
///
/// Concurrency rules (the actor is reentrant at every `await`):
/// - consent is read once, synchronously, in `init`, and only changed by `grantConsent`/`revokeConsent`, so no
///   suspended read can overwrite a newer decision;
/// - consent is checked again before each envelope, and `revokeConsent` cancels the running flush before any
///   suspension, so nothing leaves the device after a revoke (at most the request already in flight);
/// - nothing here waits for the network except `flush()`, which callers use only when they want to wait.
actor SentinelClient {

    // MARK: - Properties

    private let options: Options

    private let transport: Transport

    private let store: EventStore

    private let consentStore: any ConsentStore

    private let builder: EventBuilder

    private let now: @Sendable () -> Date

    private let appBinaryName: String?

    private let crashSnapshots: CrashSnapshotStore?

    private var scope = Scope()

    private var consent: ConsentState

    private var delivery = DeliveryState()

    private var flushTask: Task<Void, Never>?

    private var flushID: UUID?

    private var needsAnotherPass = false

    private var retryTask: Task<Void, Never>?

    private var retryID: UUID?

    /// Whether the consent rules allow sending right now (read synchronously, never across an `await`).
    private var canSend: Bool {
        switch options.consent {
        case .notRequired:
            consent != .revoked

        case .required:
            consent == .granted
        }
    }

    // MARK: - Initializer

    init(
        dsn: DSN,
        options: Options,
        httpClient: any HTTPClient,
        store: EventStore,
        consentStore: any ConsentStore,
        contexts: Contexts,
        stackTraceBuilder: StackTraceBuilder,
        appBinaryName: String? = nil,
        crashSnapshots: CrashSnapshotStore? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.options = options
        self.store = store
        self.consentStore = consentStore
        self.now = now
        self.appBinaryName = appBinaryName
        self.crashSnapshots = crashSnapshots
        consent = consentStore.load()
        transport = Transport(dsn: dsn, client: httpClient, now: now)
        builder = EventBuilder(options: options, contexts: contexts, stackTraceBuilder: stackTraceBuilder)
        crashSnapshots?.update(
            CrashSnapshot(
                location: store.location,
                options: options,
                contexts: contexts,
                scope: Scope(),
                consentAllowsCapture: consent != .revoked,
                stackTraceBuilder: stackTraceBuilder
            )
        )
    }

    // MARK: - Capture

    func capture(error: any Error, addresses: [UInt]) async {
        guard consent != .revoked else {
            return
        }

        await enqueue(builder.event(for: error, addresses: addresses, scope: scope, at: now()))
    }

    func capture(message: String, level: Level) async {
        guard consent != .revoked else {
            return
        }

        await enqueue(builder.event(message: message, level: level, scope: scope, at: now()))
    }

    func addBreadcrumb(_ breadcrumb: Breadcrumb) {
        scope.add(breadcrumb)
        publishCrashSnapshot()
    }

    func setCustom(_ key: String, _ value: String?) {
        scope.setCustom(key, value)
        publishCrashSnapshot()
    }

    /// Crashes of earlier sessions reported by MetricKit.
    func processMetricKitPayloads(_ deliveries: [MetricKitDelivery]) async {
        guard consent != .revoked else {
            return
        }

        let parser = MetricKitCrashParser(appBinaryName: appBinaryName, options: options, contexts: builder.contexts)

        for delivery in deliveries {
            let handlerCrash = CrashWriter.handlerCrashDate(in: store.directory, now: now())

            guard let result = try? parser.parse(delivery, handlerCrash: handlerCrash) else {
                Log.sdk.error("A MetricKit payload could not be read; it was skipped.")
                continue
            }

            if result.matchedHandlerCrash {
                CrashWriter.removeMarker(in: store.directory)
            }

            for event in result.events {
                await enqueue(event)
            }
        }
    }

    // MARK: - Consent

    /// Sends what was waiting, in the background.
    func grantConsent() {
        consent = .granted
        consentStore.save(.granted)
        publishCrashSnapshot()
        startFlush()
    }

    /// Stops sending at once, deletes everything waiting on the device and stops capturing.
    func revokeConsent() async {
        consent = .revoked
        consentStore.save(.revoked)
        publishCrashSnapshot()
        cancelDelivery()
        CrashWriter.removeMarker(in: store.directory)
        try? await store.removeAll()
    }

    // MARK: - Delivery

    /// The network came back: retry now instead of waiting for the backoff. Returns without waiting for the send.
    func connectivityRestored() {
        delivery.connectivityRestored()
        startFlush()
    }

    /// Starts sending in the background without waiting (app lifecycle, launch).
    func triggerFlush() {
        startFlush()
    }

    /// Sends the queue, oldest first, and waits for it. Concurrent calls join the flush already running.
    func flush() async {
        await startFlush().value
    }

    // MARK: - Private Methods

    /// What the uncaught-exception handler needs if the app crashes now.
    private func makeCrashSnapshot() -> CrashSnapshot {
        CrashSnapshot(
            location: store.location,
            options: options,
            contexts: builder.contexts,
            scope: scope,
            consentAllowsCapture: consent != .revoked,
            stackTraceBuilder: builder.stackTraceBuilder
        )
    }

    private func publishCrashSnapshot() {
        crashSnapshots?.update(makeCrashSnapshot())
    }

    private func enqueue(_ event: Event) async {
        do {
            let envelope = try Envelope(event: event, sentAt: now())

            try await store.save(EnvelopeEncoder().encode(envelope), id: event.eventID)
        } catch {
            Log.sdk.error("Could not store an event: \(error.localizedDescription, privacy: .public)")
            return
        }

        startFlush()
    }

    /// Starts a flush, or asks the running one for another pass so envelopes saved meanwhile are not left behind.
    @discardableResult
    private func startFlush() -> Task<Void, Never> {
        if let flushTask {
            needsAnotherPass = true
            return flushTask
        }

        let id = UUID()
        let task = Task {
            await drain()
            finishFlush(id)
        }

        flushTask = task
        flushID = id
        return task
    }

    private func finishFlush(_ id: UUID) {
        guard flushID == id else {
            return
        }

        flushTask = nil
        flushID = nil
    }

    private func cancelDelivery() {
        flushTask?.cancel()
        flushTask = nil
        flushID = nil
        retryTask?.cancel()
        retryTask = nil
        retryID = nil
    }

    /// Sends until the queue is empty or delivery has to stop.
    private func drain() async {
        repeat {
            needsAnotherPass = false

            guard let pending = try? await store.pending() else {
                return
            }

            for envelope in pending {
                guard await send(envelope) else {
                    scheduleRetry()
                    return
                }
            }
        } while needsAnotherPass && !Task.isCancelled
    }

    /// `true` when the envelope left the queue and the next one may be sent.
    private func send(_ envelope: StoredEnvelope) async -> Bool {
        guard canSend, !Task.isCancelled, delivery.canSend(at: now()) else {
            return false
        }

        // The queue may have recycled this envelope (10-item limit) since the list was read: skip it.
        guard let body = try? Data(contentsOf: envelope.url) else {
            return !FileManager.default.fileExists(atPath: envelope.url.path)
        }

        guard let result = try? await transport.send(encoded: body), canSend else {
            return false
        }

        if case let .rejected(statusCode) = result {
            Log.sdk.notice("The server refused an event (HTTP \(statusCode, privacy: .public)); it was dropped.")
        }

        guard delivery.record(result, at: now()) == .delete else {
            return false
        }

        do {
            try await store.remove(envelope)
            return true
        } catch {
            // Already recycled by the queue: fine. Still on disk: stop, or it would be sent again forever.
            return !FileManager.default.fileExists(atPath: envelope.url.path)
        }
    }

    /// After a failure, tries again when the backoff or the rate limit ends (launch, network and lifecycle also
    /// trigger a flush).
    private func scheduleRetry() {
        guard canSend, let date = delivery.nextAttempt, retryTask == nil else {
            return
        }

        let delay = max(1, date.timeIntervalSince(now()))
        let id = UUID()

        retryID = id
        retryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            retryFired(id)
        }
    }

    /// Ignores a retry task that was cancelled or replaced meanwhile.
    private func retryFired(_ id: UUID) {
        guard retryID == id else {
            return
        }

        retryTask = nil
        retryID = nil

        guard !Task.isCancelled else {
            return
        }

        startFlush()
    }
}
