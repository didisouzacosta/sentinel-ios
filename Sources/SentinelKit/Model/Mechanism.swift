/// How an exception was captured: by the app (`handled: true`) or by a crash handler (`handled: false`).
struct Mechanism: Hashable, Sendable, Encodable {

    // MARK: - Properties

    var type: String

    var handled: Bool
}
