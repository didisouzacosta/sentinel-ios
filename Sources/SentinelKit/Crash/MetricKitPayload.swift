/// The parts of `MXDiagnosticPayload.jsonRepresentation()` the SDK reads. Everything is optional so one malformed
/// diagnostic does not discard the others.
struct MetricKitPayload: Decodable {

    // MARK: - Fields

    let timeStampBegin: String?

    let timeStampEnd: String?

    let crashDiagnostics: [Diagnostic]?

    // MARK: - Types

    struct Diagnostic: Decodable {
        let diagnosticMetaData: MetaData?
        let callStackTree: CallStackTree?
    }

    struct MetaData: Decodable {

        // MARK: - Fields

        let appVersion: String?
        let appBuildVersion: String?
        let bundleIdentifier: String?
        let osVersion: String?
        let deviceType: String?
        let platformArchitecture: String?
        let exceptionType: Int?
        let exceptionCode: Int?
        let signal: Int?
        let terminationReason: String?
        let objectiveCexceptionReason: ObjectiveCReason?
    }

    struct ObjectiveCReason: Decodable {
        let composedMessage: String?
        let exceptionName: String?
    }

    struct CallStackTree: Decodable {
        let callStacks: [CallStack]?
    }

    struct CallStack: Decodable {
        let threadAttributed: Bool?
        let callStackRootFrames: [Frame]?
    }

    /// A frame and, in `subFrames`, the frame that called it.
    struct Frame: Decodable {
        let binaryUUID: String?
        let binaryName: String?
        let address: UInt?
        let offsetIntoBinaryTextSegment: UInt?
        let subFrames: [Frame]?
    }
}
