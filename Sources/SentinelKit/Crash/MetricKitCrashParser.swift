import Foundation

/// Turns MetricKit crash diagnostics (delivered by iOS on a later launch) into fatal events.
///
/// The crashed thread's frames keep their raw addresses, binary names and UUIDs (`debug_meta`): the server does not
/// symbolicate yet, so function names stay empty until it does. Breadcrumbs and custom parameters of the crashed
/// session are not available to MetricKit, so they are not attached. The release, OS version and device model come
/// from the diagnostic (the build that crashed), not from the current launch.
struct MetricKitCrashParser: Sendable {

    // MARK: - Properties

    /// The app's executable name (`CFBundleExecutable`); its frames count as in-app.
    let appBinaryName: String?

    let options: Options

    let contexts: Contexts

    // MARK: - Type Methods

    /// Load address of the binary: the frame's address minus its offset into the binary's text segment.
    private static func imageAddress(of frame: MetricKitPayload.Frame) -> UInt? {
        guard let address = frame.address, let offset = frame.offsetIntoBinaryTextSegment, offset <= address else {
            return nil
        }

        return address - offset
    }

    private static func hex(_ value: UInt) -> String {
        let digits = String(value, radix: 16)

        return "0x" + String(repeating: "0", count: max(0, 16 - digits.count)) + digits
    }

    /// Fallback when the payload's `Date` is missing: MetricKit writes `yyyy-MM-dd HH:mm:ss` without a time zone,
    /// read here as UTC.
    private static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }

    /// `"iPhone OS 26.1 (23B85)"` → (`"26.1"`, `"23B85"`).
    private static func osVersion(from text: String) -> (version: String, build: String?)? {
        let pattern = #"([0-9]+(?:\.[0-9]+)*)(?: \(([A-Za-z0-9]+)\))?"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let versionRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return (String(text[versionRange]), Range(match.range(at: 2), in: text).map { String(text[$0]) })
    }

    /// The window may be missing; a small tolerance absorbs rounding to minutes.
    private static func isWithin(_ date: Date, begin: Date?, end: Date?) -> Bool {
        let tolerance: TimeInterval = 120

        if let begin, date < begin.addingTimeInterval(-tolerance) {
            return false
        }

        if let end, date > end.addingTimeInterval(tolerance) {
            return false
        }

        return true
    }

    // MARK: - Methods

    /// - Parameter handlerCrash: when the NSException handler wrote a crash (from its marker). The first
    ///   Objective-C exception or `EXC_CRASH`/`SIGABRT` diagnostic in this payload's window is that same crash and
    ///   is skipped.
    func parse(_ delivery: MetricKitDelivery, handlerCrash: Date?) throws -> MetricKitParseResult {
        let payload = try JSONDecoder().decode(MetricKitPayload.self, from: delivery.json)
        let begin = delivery.begin ?? payload.timeStampBegin.flatMap(Self.date(from:))
        let end = delivery.end ?? payload.timeStampEnd.flatMap(Self.date(from:))
        let timestamp = end ?? Date()
        let duplicate = handlerCrash.map { Self.isWithin($0, begin: begin, end: end) } ?? false

        var matched = false
        var events: [Event] = []

        for diagnostic in payload.crashDiagnostics ?? [] {
            guard let metaData = diagnostic.diagnosticMetaData else {
                continue
            }

            let looksLikeHandlerCrash = metaData.objectiveCexceptionReason != nil || MachException.isAbort(metaData)

            if duplicate, !matched, looksLikeHandlerCrash {
                matched = true
                continue
            }

            events.append(event(for: diagnostic, metaData: metaData, at: timestamp))
        }

        return MetricKitParseResult(events: events, matchedHandlerCrash: matched)
    }

    // MARK: - Private Methods

    private func event(
        for diagnostic: MetricKitPayload.Diagnostic,
        metaData: MetricKitPayload.MetaData,
        at timestamp: Date
    ) -> Event {
        let chain = crashedThreadChain(diagnostic.callStackTree)

        var event = Event(timestamp: timestamp, level: .fatal)
        event.release = release(metaData) ?? options.release
        event.environment = options.environment
        event.dist = options.dist
        event.contexts = crashedContexts(metaData)
        event.exception = ExceptionList(
            values: [
                ExceptionValue(
                    type: exceptionType(metaData),
                    value: exceptionValue(metaData),
                    mechanism: Mechanism(type: metaData.exceptionType == nil ? "signal" : "mach", handled: false),
                    stacktrace: chain.isEmpty ? nil : Stacktrace(frames: chain.reversed().map(stackFrame(for:)))
                ),
            ]
        )
        event.debugMeta = debugMeta(for: chain)
        return event
    }

    private func exceptionType(_ metaData: MetricKitPayload.MetaData) -> String {
        metaData.objectiveCexceptionReason?.exceptionName
            ?? MachException.exceptionName(metaData.exceptionType)
            ?? MachException.signalName(metaData.signal)
            ?? "Crash"
    }

    private func exceptionValue(_ metaData: MetricKitPayload.MetaData) -> String {
        if let message = metaData.objectiveCexceptionReason?.composedMessage {
            return message
        }

        return [MachException.signalName(metaData.signal), metaData.terminationReason]
            .compactMap(\.self)
            .joined(separator: ": ")
    }

    /// Frames of the crashed thread, newest first: the root frame, then each first sub-frame (its caller).
    private func crashedThreadChain(_ tree: MetricKitPayload.CallStackTree?) -> [MetricKitPayload.Frame] {
        let stacks = tree?.callStacks ?? []
        let crashed = stacks.first { $0.threadAttributed == true } ?? stacks.first

        var chain: [MetricKitPayload.Frame] = []
        var frame = crashed?.callStackRootFrames?.first

        while let current = frame {
            chain.append(current)
            frame = current.subFrames?.first
        }

        return chain
    }

    private func stackFrame(for frame: MetricKitPayload.Frame) -> StackFrame {
        StackFrame(
            package: frame.binaryName,
            instructionAddress: frame.address.map(Self.hex),
            imageAddress: Self.imageAddress(of: frame).map(Self.hex),
            inApp: frame.binaryName != nil && frame.binaryName == appBinaryName
        )
    }

    private func debugMeta(for chain: [MetricKitPayload.Frame]) -> DebugMeta? {
        var seen: Set<String> = []
        var images: [DebugImage] = []

        for frame in chain {
            guard
                let uuid = frame.binaryUUID?.lowercased(), let base = Self.imageAddress(of: frame),
                seen.insert(uuid).inserted
            else {
                continue
            }

            images.append(DebugImage(debugID: uuid, imageAddress: Self.hex(base), codeFile: frame.binaryName))
        }

        return images.isEmpty ? nil : DebugMeta(images: images)
    }

    /// The build that crashed: its bundle id (or the current one) with the diagnostic's version and build. MetricKit
    /// crashes always use this form, even when the app sets a custom `options.release`, because the custom value
    /// describes the current build, not the one that crashed.
    private func release(_ metaData: MetricKitPayload.MetaData) -> String? {
        AppInfo(
            identifier: metaData.bundleIdentifier ?? contexts.app?.identifier,
            name: nil,
            version: metaData.appVersion,
            build: metaData.appBuildVersion
        ).release
    }

    private func crashedContexts(_ metaData: MetricKitPayload.MetaData) -> Contexts {
        var crashed = contexts

        if let current = contexts.operatingSystem, let parsed = metaData.osVersion.flatMap(Self.osVersion(from:)) {
            crashed.operatingSystem = OSContext(name: current.name, version: parsed.version, build: parsed.build)
        }

        if let device = contexts.device, let model = metaData.deviceType {
            crashed.device = DeviceContext(
                model: model,
                family: device.family,
                arch: metaData.platformArchitecture ?? device.arch,
                simulator: false,
                memorySize: device.memorySize
            )
        }

        return crashed
    }
}
