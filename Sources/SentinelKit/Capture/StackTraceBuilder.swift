import Foundation

/// Builds stack frames from return addresses, resolving symbol and image on the device with `dladdr`.
///
/// The server does not symbolicate, so `function` and `package` are filled here; the addresses are kept for a
/// future server-side symbolication of stripped release builds.
struct StackTraceBuilder: Sendable {

    // MARK: - Type Properties

    /// Frames inside the main app bundle count as in-app.
    static var app: StackTraceBuilder {
        let bundlePath = Bundle.main.bundlePath

        return StackTraceBuilder { $0.hasPrefix(bundlePath) }
    }

    // MARK: - Properties

    /// Decides whether a frame belongs to the app, from the path of the image that contains it.
    let isInApp: @Sendable (String) -> Bool

    // MARK: - Initializer

    init(isInApp: @escaping @Sendable (String) -> Bool) {
        self.isInApp = isInApp
    }

    // MARK: - Type Methods

    /// Return addresses of the current thread, newest first.
    static func currentAddresses() -> [UInt] {
        Thread.callStackReturnAddresses.map(\.uintValue)
    }

    /// Demangled names may start with `static`, `closure #1 in` and so on, so look for the module anywhere.
    /// Only frames at the top of the stack are dropped. An app frame whose signature mentions a SentinelKit type would
    /// also match, and in stripped release builds `dladdr` names are approximate; both only cost a missing top frame.
    private static func isSDKFrame(_ frame: StackFrame) -> Bool {
        frame.function?.contains("SentinelKit.") ?? false
    }

    private static func hex(_ value: UInt) -> String {
        let digits = String(value, radix: 16)

        return "0x" + String(repeating: "0", count: max(0, 16 - digits.count)) + digits
    }

    // MARK: - Methods

    /// Frames oldest first (the order the server expects), without the SDK's own frames at the top.
    func frames(from addresses: [UInt]) -> [StackFrame] {
        let frames = addresses.map(frame(for:))
        let firstAppFrame = frames.firstIndex { !Self.isSDKFrame($0) } ?? frames.endIndex

        return Array(frames[firstAppFrame...].reversed())
    }

    private func frame(for address: UInt) -> StackFrame {
        var info = Dl_info()

        guard let pointer = UnsafeRawPointer(bitPattern: address), dladdr(pointer, &info) != 0 else {
            return StackFrame(instructionAddress: Self.hex(address))
        }

        let imagePath = info.dli_fname.map { String(cString: $0) }
        let symbol = info.dli_sname.map { SymbolDemangler.demangle(String(cString: $0)) }
        let imageAddress = info.dli_fbase.map { UInt(bitPattern: $0) }

        return StackFrame(
            function: symbol,
            package: imagePath.map { URL(fileURLWithPath: $0).lastPathComponent },
            instructionAddress: Self.hex(address),
            imageAddress: imageAddress.map(Self.hex),
            inApp: imagePath.map(isInApp) ?? false
        )
    }
}
