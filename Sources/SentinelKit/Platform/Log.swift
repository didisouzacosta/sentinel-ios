import os

/// SDK diagnostics in the system log. Never logs event contents.
enum Log {
    static let sdk = Logger(subsystem: "SentinelKit", category: "SDK")
}
