/// Readable names for the Mach exception types and signals MetricKit reports as numbers.
enum MachException {

    // MARK: - Names

    static func exceptionName(_ type: Int?) -> String? {
        switch type {
        case 1: "EXC_BAD_ACCESS"
        case 2: "EXC_BAD_INSTRUCTION"
        case 3: "EXC_ARITHMETIC"
        case 4: "EXC_EMULATION"
        case 5: "EXC_SOFTWARE"
        case 6: "EXC_BREAKPOINT"
        case 10: "EXC_CRASH"
        case 11: "EXC_RESOURCE"
        case 12: "EXC_GUARD"
        default: nil
        }
    }

    static func signalName(_ signal: Int?) -> String? {
        switch signal {
        case 4: "SIGILL"
        case 5: "SIGTRAP"
        case 6: "SIGABRT"
        case 8: "SIGFPE"
        case 9: "SIGKILL"
        case 10: "SIGBUS"
        case 11: "SIGSEGV"
        case 13: "SIGPIPE"
        default: signal.map { "Signal \($0)" }
        }
    }

    /// `EXC_CRASH` with `SIGABRT`: what an uncaught `NSException` (or `abort()`) looks like.
    static func isAbort(_ metaData: MetricKitPayload.MetaData) -> Bool {
        metaData.exceptionType == 10 && metaData.signal == 6
    }
}
