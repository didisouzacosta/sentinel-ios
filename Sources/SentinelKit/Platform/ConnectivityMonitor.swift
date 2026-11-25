import Network

/// Reports whether the device has a usable network path, so the queue is sent as soon as the network comes back.
enum ConnectivityMonitor {

    // MARK: - Methods

    /// `true` when online. Starts on iteration and stops when the stream ends.
    static func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }

            continuation.onTermination = { _ in
                monitor.cancel()
            }

            // NWPathMonitor only delivers updates on a dispatch queue; this private serial queue is its sole use.
            monitor.start(queue: DispatchQueue(label: "SentinelKit.connectivity"))
        }
    }
}
