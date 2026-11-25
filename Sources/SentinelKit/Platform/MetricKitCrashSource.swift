#if canImport(MetricKit) && os(iOS)
    import MetricKit

    /// Receives MetricKit diagnostics (crashes of earlier sessions, delivered on launch) and queues them as JSON.
    final class MetricKitCrashSource: NSObject, MXMetricManagerSubscriber, Sendable {

        // MARK: - Properties

        private let hub: SentinelHub

        // MARK: - Initializer

        init(hub: SentinelHub) {
            self.hub = hub
        }

        // MARK: - Methods

        /// Subscribes to MetricKit. The caller keeps the returned source alive.
        static func register(hub: SentinelHub) -> MetricKitCrashSource {
            let source = MetricKitCrashSource(hub: hub)

            MXMetricManager.shared.add(source)
            return source
        }

        // MARK: - MXMetricManagerSubscriber

        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            let deliveries = payloads.map { payload in
                MetricKitDelivery(
                    json: payload.jsonRepresentation(),
                    begin: payload.timeStampBegin,
                    end: payload.timeStampEnd
                )
            }

            hub.send(.metricKitPayloads(deliveries))
        }
    }
#endif
