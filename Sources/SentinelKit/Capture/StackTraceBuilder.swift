import Foundation

/// Builds stack frames from return addresses, resolving symbol and image on the device with `dladdr`, and lists the
/// images those frames point into as `debug_meta`.
///
/// The server does not symbolicate yet, so `function` and `package` are filled here; the addresses and each image's
/// UUID, load address and size let a server that has the uploaded dSYM match the binaries.
struct StackTraceBuilder: Sendable {

    // MARK: - Type Properties

    /// Frames inside the main app bundle count as in-app; the directory holding the bundle is left out of
    /// `code_file`.
    static var app: StackTraceBuilder {
        let bundlePath = Bundle.main.bundlePath

        return StackTraceBuilder(
            isInApp: { $0.hasPrefix(bundlePath) },
            appContainerPath: URL(fileURLWithPath: bundlePath).deletingLastPathComponent().path
        )
    }

    // MARK: - Properties

    /// Decides whether a frame belongs to the app, from the path of the image that contains it.
    let isInApp: @Sendable (String) -> Bool

    /// The directory holding the app bundle, removed from `code_file` so the install path (with its per-install
    /// container UUID, or the user name on a simulator) is not sent. Nil keeps full paths.
    let appContainerPath: String?

    // MARK: - Initializer

    init(isInApp: @escaping @Sendable (String) -> Bool, appContainerPath: String? = nil) {
        self.isInApp = isInApp
        self.appContainerPath = appContainerPath
    }

    // MARK: - Type Methods

    /// Return addresses of the current thread, newest first.
    static func currentAddresses() -> [UInt] {
        Thread.callStackReturnAddresses.map(\.uintValue)
    }

    /// `path` relative to the app's container when it lies inside it (`Shop.app/Shop`), otherwise unchanged
    /// (`/usr/lib/libobjc.A.dylib`).
    static func codeFile(for path: String, appContainerPath: String?) -> String {
        guard let appContainerPath, path.hasPrefix(appContainerPath + "/") else {
            return path
        }

        return String(path.dropFirst(appContainerPath.count + 1))
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

    /// One image per load address, in order of first reference. Each header is read once per stack; an image whose
    /// header cannot be read is left out, and its frames keep their `image_addr`.
    private static func debugImages(for frames: [ResolvedFrame], appContainerPath: String?) -> [DebugImage] {
        var seen: Set<UInt> = []

        var images: [DebugImage] = []

        for frame in frames {
            guard let base = frame.imageBase, seen.insert(base).inserted else {
                continue
            }

            guard let image = UnsafeRawPointer(bitPattern: base).flatMap(MachOImage.init(header:)) else {
                continue
            }

            images.append(
                DebugImage(
                    debugID: image.debugID,
                    imageAddress: hex(base),
                    codeFile: frame.imagePath.map { codeFile(for: $0, appContainerPath: appContainerPath) },
                    imageSize: image.imageSize,
                    arch: image.arch
                )
            )
        }

        return images
    }

    // MARK: - Methods

    /// Frames oldest first (the order the server expects), without the SDK's own frames at the top, and the images
    /// those frames point into.
    func resolve(_ addresses: [UInt]) -> ResolvedStackTrace {
        let resolved = addresses.map(resolvedFrame(at:))
        let firstAppFrame = resolved.firstIndex { !Self.isSDKFrame($0.frame) } ?? resolved.endIndex
        let kept = Array(resolved[firstAppFrame...].reversed())

        return ResolvedStackTrace(
            frames: kept.map(\.frame),
            images: Self.debugImages(for: kept, appContainerPath: appContainerPath)
        )
    }

    private func resolvedFrame(at address: UInt) -> ResolvedFrame {
        var info = Dl_info()

        guard let pointer = UnsafeRawPointer(bitPattern: address), dladdr(pointer, &info) != 0 else {
            return ResolvedFrame(
                frame: StackFrame(instructionAddress: Self.hex(address)),
                imageBase: nil,
                imagePath: nil
            )
        }

        let imagePath = info.dli_fname.map { String(cString: $0) }
        let symbol = info.dli_sname.map { SymbolDemangler.demangle(String(cString: $0)) }
        let imageBase = info.dli_fbase.map { UInt(bitPattern: $0) }
        let frame = StackFrame(
            function: symbol,
            package: imagePath.map { URL(fileURLWithPath: $0).lastPathComponent },
            instructionAddress: Self.hex(address),
            imageAddress: imageBase.map(Self.hex),
            inApp: imagePath.map(isInApp) ?? false
        )

        return ResolvedFrame(frame: frame, imageBase: imageBase, imagePath: imagePath)
    }

    // MARK: - Resolved Frame

    /// A frame with the load address and path of its image, kept until the images are listed.
    private struct ResolvedFrame {
        let frame: StackFrame

        let imageBase: UInt?

        let imagePath: String?
    }
}
