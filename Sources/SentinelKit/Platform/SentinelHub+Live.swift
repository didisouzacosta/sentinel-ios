import Foundation

extension SentinelHub {

    // MARK: - Production

    /// The app's single hub: consent in `UserDefaults`, the queue in `Caches/SentinelKit/`.
    static let live = SentinelHub(
        consentStore: UserDefaultsConsentStore(),
        store: EventStore(directory: EventStore.defaultDirectory()),
        makeClient: liveClient
    )

    /// The production engine over `URLSession`.
    static let liveClient: ClientFactory = { dsn, options, consentStore, store in
        guard let dsn = try? DSN(dsn) else {
            return nil
        }

        return SentinelClient(
            dsn: dsn,
            options: options,
            httpClient: URLSessionHTTPClient(),
            store: store,
            consentStore: consentStore,
            contexts: ContextProvider.contexts(app: AppInfo(bundle: .main)),
            stackTraceBuilder: .app
        )
    }
}
