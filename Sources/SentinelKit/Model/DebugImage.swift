/// A binary the event's frames point into, identified by its UUID so a symbolicator can find its dSYM.
struct DebugImage: Hashable, Sendable, Encodable {

    // MARK: - Properties

    let type = "macho"

    /// The binary's UUID, lowercased, with dashes (the dSYM debug id).
    let debugID: String

    let imageAddress: String

    let codeFile: String?

    /// `__TEXT` size in bytes; omitted when unknown, as in MetricKit reports.
    let imageSize: UInt64?

    /// `arm64`, `arm64e`, `x86_64` or `arm64_32`; omitted when unknown, as in MetricKit reports.
    let arch: String?

    // MARK: - Initializer

    init(debugID: String, imageAddress: String, codeFile: String?, imageSize: UInt64? = nil, arch: String? = nil) {
        self.debugID = debugID
        self.imageAddress = imageAddress
        self.codeFile = codeFile
        self.imageSize = imageSize
        self.arch = arch
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case type
        case debugID = "debug_id"
        case imageAddress = "image_addr"
        case codeFile = "code_file"
        case imageSize = "image_size"
        case arch
    }
}
