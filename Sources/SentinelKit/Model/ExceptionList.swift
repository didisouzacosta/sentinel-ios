/// The `exception` field of an event. The server reads the first value for title and grouping.
struct ExceptionList: Hashable, Sendable, Encodable {
    var values: [ExceptionValue]
}
