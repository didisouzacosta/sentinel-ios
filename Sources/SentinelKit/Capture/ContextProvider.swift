import Foundation

/// Reads the app, OS and device contexts once, without UIKit and without anything that identifies the person.
enum ContextProvider {

    // MARK: - Platform

    private static var osName: String {
        #if os(iOS)
            "iOS"
        #elseif os(macOS)
            "macOS"
        #else
            "Apple"
        #endif
    }

    private static var architecture: String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #else
            "unknown"
        #endif
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    // MARK: - Methods

    static func contexts(app: AppInfo) -> Contexts {
        Contexts(
            app: AppContext(identifier: app.identifier, name: app.name, version: app.version, build: app.build),
            operatingSystem: operatingSystem(),
            device: device()
        )
    }

    // MARK: - Private Methods

    private static func operatingSystem() -> OSContext {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return OSContext(
            name: osName,
            version: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            build: sysctlString("kern.osversion")
        )
    }

    private static func device() -> DeviceContext {
        DeviceContext(
            model: modelIdentifier(),
            family: osName,
            arch: architecture,
            simulator: isSimulator,
            memorySize: ProcessInfo.processInfo.physicalMemory
        )
    }

    /// `iPhone17,1` on a device; on the simulator, the model it simulates.
    private static func modelIdentifier() -> String {
        if isSimulator, let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        return sysctlString("hw.machine") ?? sysctlString("hw.model") ?? "unknown"
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0

        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)

        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        return String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8)
    }
}
