/// A binary loaded when the crash happened, identified by its UUID so a symbolicator can find its dSYM.
struct DebugImage: Hashable, Sendable, Encodable {

    // MARK: - Properties

    let type = "macho"

    /// The binary's UUID, lowercased, with dashes (the dSYM debug id).
    let debugID: String

    let imageAddress: String

    let codeFile: String?

    // MARK: - Initializer

    init(debugID: String, imageAddress: String, codeFile: String?) {
        self.debugID = debugID
        self.imageAddress = imageAddress
        self.codeFile = codeFile
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case type
        case debugID = "debug_id"
        case imageAddress = "image_addr"
        case codeFile = "code_file"
    }
}
