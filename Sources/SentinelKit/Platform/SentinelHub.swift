import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// Turns the synchronous public API into ordered work for the engine.
///
/// Calls are yielded into an `AsyncStream` (ordered, never blocking the caller) and handled one by one by a single
/// task. No command waits for the network, so captures reach the disk right away. The task lives as long as the
/// hub; the app has exactly one hub (`Sentinel`), tests create their own.
final class SentinelHub: Sendable {

    // MARK: - Types

    typealias ClientFactory = @Sendable (
        _ dsn: String,
        _ options: Options,
        _ consentStore: any ConsentStore,
        _ store: EventStore
    ) -> SentinelClient?

    // MARK: - Properties

    private let continuation: AsyncStream<SentinelCommand>.Continuation

    // MARK: - Initializer

    /// - Parameters:
    ///   - consentStore: also used before `start`, so a consent decision is never lost.
    ///   - store: the offline queue; a revoke before `start` clears it too.
    ///   - observesSystem: watches the network and the app lifecycle to send the queue (off in tests).
    init(
        consentStore: any ConsentStore,
        store: EventStore,
        observesSystem: Bool = true,
        makeClient: @escaping ClientFactory
    ) {
        let (stream, continuation) = AsyncStream.makeStream(of: SentinelCommand.self)
        let context = Context(consentStore: consentStore, store: store, makeClient: makeClient)

        self.continuation = continuation

        Task {
            await Self.run(stream, context: context, observesSystem: observesSystem, hub: self)
        }
    }

    // MARK: - Type Methods

    private static func run(
        _ commands: AsyncStream<SentinelCommand>,
        context: Context,
        observesSystem: Bool,
        hub: SentinelHub
    ) async {
        var client: SentinelClient?

        for await command in commands {
            if case let .start(dsn, options) = command {
                client = await start(current: client, dsn: dsn, options: options, context: context)

                if client != nil, observesSystem {
                    observeSystem(hub: hub)
                }

                continue
            }

            if let client {
                await handle(command, client: client)
            } else {
                await handleWithoutClient(command, context: context)
            }
        }
    }

    private static func start(
        current: SentinelClient?,
        dsn: String,
        options: Options,
        context: Context
    ) async -> SentinelClient? {
        guard current == nil else {
            Log.sdk.warning("Sentinel.start was called more than once; the first configuration is kept.")
            return current
        }

        guard let client = context.makeClient(dsn, options, context.consentStore, context.store) else {
            Log.sdk.error("Invalid DSN: the SDK stays off. Copy it from Project settings → Client keys.")
            return nil
        }

        await client.triggerFlush()
        return client
    }

    private static func handle(_ command: SentinelCommand, client: SentinelClient) async {
        switch command {
        case let .captureError(error, addresses):
            await client.capture(error: error, addresses: addresses)

        case let .captureMessage(message, level):
            await client.capture(message: message, level: level)

        case let .breadcrumb(breadcrumb):
            await client.addBreadcrumb(breadcrumb)

        case let .custom(key, value):
            await client.setCustom(key, value)

        default:
            await handleState(command, client: client)
        }
    }

    /// Consent, delivery and synchronization commands.
    private static func handleState(_ command: SentinelCommand, client: SentinelClient) async {
        switch command {
        case .grantConsent:
            await client.grantConsent()

        case .revokeConsent:
            await client.revokeConsent()

        case .connectivityRestored:
            await client.connectivityRestored()

        case .triggerFlush:
            await client.triggerFlush()

        case let .flush(done):
            Task {
                await client.flush()
                done.resume()
            }

        case let .barrier(done):
            done.resume()

        default:
            return
        }
    }

    /// Before `start` (or with an invalid DSN) nothing is captured, but consent decisions still count.
    private static func handleWithoutClient(_ command: SentinelCommand, context: Context) async {
        switch command {
        case .grantConsent:
            context.consentStore.save(.granted)

        case .revokeConsent:
            context.consentStore.save(.revoked)
            try? await context.store.removeAll()

        case let .flush(done), let .barrier(done):
            done.resume()

        default:
            return
        }
    }

    /// Sends the queue when the network comes back and when the app goes to or returns from the background.
    private static func observeSystem(hub: SentinelHub) {
        Task {
            var wasOnline = true

            for await isOnline in ConnectivityMonitor.updates() {
                if isOnline, !wasOnline {
                    hub.send(.connectivityRestored)
                }

                wasOnline = isOnline
            }
        }

        #if canImport(UIKit)
            for name in [UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification] {
                Task {
                    for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
                        hub.send(.triggerFlush)
                    }
                }
            }
        #endif
    }

    // MARK: - Methods

    func send(_ command: SentinelCommand) {
        continuation.yield(command)
    }

    // MARK: - Context

    /// What the command loop needs, with or without a started client.
    private struct Context: Sendable {
        let consentStore: any ConsentStore
        let store: EventStore
        let makeClient: ClientFactory
    }
}
