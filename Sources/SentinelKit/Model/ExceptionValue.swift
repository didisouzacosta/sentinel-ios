/// One exception: its type, message, how it was captured and where it happened.
struct ExceptionValue: Hashable, Sendable, Encodable {

    // MARK: - Properties

    var type: String

    var value: String?

    var mechanism: Mechanism?

    var stacktrace: Stacktrace?

    // MARK: - Initializer

    init(type: String, value: String? = nil, mechanism: Mechanism? = nil, stacktrace: Stacktrace? = nil) {
        self.type = type
        self.value = value
        self.mechanism = mechanism
        self.stacktrace = stacktrace
    }
}
