/// One frame of a stack trace. The server groups and displays by `function`, `filename` and `lineno`;
/// the addresses are kept for symbolication.
struct StackFrame: Hashable, Sendable, Encodable {

    // MARK: - Properties

    var function: String?

    var filename: String?

    var lineNumber: Int?

    var package: String?

    var instructionAddress: String?

    var imageAddress: String?

    var inApp: Bool?

    // MARK: - Initializer

    init(
        function: String? = nil,
        filename: String? = nil,
        lineNumber: Int? = nil,
        package: String? = nil,
        instructionAddress: String? = nil,
        imageAddress: String? = nil,
        inApp: Bool? = nil
    ) {
        self.function = function
        self.filename = filename
        self.lineNumber = lineNumber
        self.package = package
        self.instructionAddress = instructionAddress
        self.imageAddress = imageAddress
        self.inApp = inApp
    }

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case function
        case filename
        case lineNumber = "lineno"
        case package
        case instructionAddress = "instruction_addr"
        case imageAddress = "image_addr"
        case inApp = "in_app"
    }
}
